/*
 * leanlink_shim.c -- Bridges Wolfram LibraryLink and Lean @[export] functions.
 *
 * Compiled together with generated Lean C files into one shared library.
 * Links against libleanshared.dylib (Lean runtime).
 *
 * Lean functions return IO results containing ByteArray (WXF bytes).
 * We extract the raw bytes and return them as a rank-1 MTensor.
 *
 * ABI note: Lean 4.29 @[export] functions:
 *  - No world token in params
 *  - Functions CONSUME their lean_object* args (caller must NOT lean_dec)
 *  - Results wrapped in Except ctor (tag 0 = ok, tag 1 = error)
 */

#include "WolframLibrary.h"
#include "lean/lean.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Lean FFI init (not in lean.h but exported from libleanshared) */
/* lean_initialize, not lean_initialize_runtime_module: a host that uses the Lean
   package must also start Lean's C++ side (kernel, library, compiler), as Lean's
   FFI notes say. With the runtime alone the IR interpreter's option names stay
   null, and the first evalConst - the pretty printer reaching a parenthesizer for
   a non-builtin syntax kind, such as a dependent if-then-else - dereferences one
   and kills the kernel. lean_initialize includes the runtime initialization and
   runs the Init, Std and Lean module initializers, which are no-ops when
   initialize_leanlink_LeanLink reaches them again. It returns void. */
extern void lean_initialize(void);
extern void lean_io_mark_end_initialization(void);
extern void lean_initialize_thread(void);

#ifdef _WIN32
#include <windows.h>
static int portable_setenv(const char *name, const char *value, int overwrite) {
    if (!overwrite && getenv(name) != NULL) {
        return 0;
    }
    return _putenv_s(name, value);
}
#ifndef CREATE_WAITABLE_TIMER_HIGH_RESOLUTION
#define CREATE_WAITABLE_TIMER_HIGH_RESOLUTION 0x00000002
#endif
/* QueryPerformanceCounter, not GetTickCount64, which moves in timer ticks of about 15.6 ms */
static uint64_t monotonic_us(void) {
    static LARGE_INTEGER freq;
    LARGE_INTEGER now;
    if (!freq.QuadPart) QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&now);
    return (uint64_t)(now.QuadPart / freq.QuadPart) * 1000000 + (uint64_t)(now.QuadPart % freq.QuadPart) * 1000000 / (uint64_t)freq.QuadPart;
}
/* Sleep(1) waits a whole timer tick, about 15.6 ms, which made every evaluation that was not done at the first
   check take that long. A high-resolution waitable timer (Windows 10 1803 and later) waits the microseconds asked
   for; without one, a wait under a millisecond only yields the thread. */
static void sleep_us(uint64_t us) {
    static _Thread_local HANDLE timer = NULL;
    static _Thread_local int timer_tried = 0;
    if (!timer_tried) {
        timer_tried = 1;
        timer = CreateWaitableTimerExW(NULL, NULL, CREATE_WAITABLE_TIMER_HIGH_RESOLUTION, TIMER_ALL_ACCESS);
    }
    if (timer) {
        LARGE_INTEGER due;
        due.QuadPart = -(LONGLONG)(us * 10); /* relative, in units of 100 ns */
        if (SetWaitableTimer(timer, &due, 0, NULL, NULL, FALSE)) {
            WaitForSingleObject(timer, INFINITE);
            return;
        }
    }
    if (us < 1000) SwitchToThread();
    else Sleep((DWORD)(us / 1000));
}
#else
#include <time.h>
static int portable_setenv(const char *name, const char *value, int overwrite) {
    return setenv(name, value, overwrite);
}
static uint64_t monotonic_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000 + (uint64_t)ts.tv_nsec / 1000;
}
static void sleep_us(uint64_t us) {
    struct timespec ts = { (time_t)(us / 1000000), (long)(us % 1000000) * 1000 };
    nanosleep(&ts, NULL);
}
#endif

/* Ensure current thread is registered with Lean runtime.
   WL may call LibraryLink functions from different threads.
   Use thread-local guard to avoid repeated initialization. */
static _Thread_local int g_thread_initialized = 0;
static void ensure_thread(void) {
    if (!g_thread_initialized) {
        lean_initialize_thread();
        g_thread_initialized = 1;
    }
}

/* Lean module initializer (v4.29: no world token, package-prefixed name) */
extern lean_object* initialize_leanlink_LeanLink(uint8_t builtin);

/* Lean @[export] functions (Lean 4.29 ABI: no world token) */
extern lean_object* leanlink_init(void);
extern lean_object* leanlink_load_env(lean_object* imports, lean_object* searchPath);
extern lean_object* leanlink_free_env(uint64_t handle);
extern lean_object* leanlink_list_theorems(uint64_t handle, lean_object* filter);
extern lean_object* leanlink_get_type(uint64_t handle, lean_object* name, uint32_t depth);
extern lean_object* leanlink_get_value(uint64_t handle, lean_object* name, uint32_t depth);
extern lean_object* leanlink_get_type_shared(uint64_t handle, lean_object* name);
extern lean_object* leanlink_get_value_shared(uint64_t handle, lean_object* name);
extern lean_object* leanlink_get_fields_table(uint64_t handle, lean_object* names);
extern lean_object* leanlink_get_bridge_cone(uint64_t handle, lean_object* roots);
extern lean_object* leanlink_get_constant(uint64_t handle, lean_object* name);
extern lean_object* leanlink_get_used_constants(uint64_t handle, lean_object* name);
extern lean_object* leanlink_collect_axioms(uint64_t handle, lean_object* name);
extern lean_object* leanlink_kernel_check(uint64_t handle, lean_object* name);
extern lean_object* leanlink_module_constant_kinds(uint64_t handle, lean_object* module);
extern lean_object* leanlink_constant_module(uint64_t handle, lean_object* name);
extern lean_object* leanlink_decl_range(uint64_t handle, lean_object* name);
extern lean_object* leanlink_list_constant_names(uint64_t handle, lean_object* filter);
extern lean_object* leanlink_list_constant_kinds(uint64_t handle, lean_object* filter);
extern lean_object* leanlink_list_constant_kinds_split(uint64_t handle, lean_object* filter, lean_object* patterns);
extern lean_object* leanlink_get_type_unfolded(uint64_t handle, lean_object* name, uint32_t unfoldLevel);
extern lean_object* leanlink_get_value_unfolded(uint64_t handle, lean_object* name, uint32_t unfoldLevel);
extern lean_object* leanlink_pp_type(uint64_t handle, lean_object* name, uint32_t unfoldLevel, lean_object* opens);
extern lean_object* leanlink_pp_value(uint64_t handle, lean_object* name, uint32_t unfoldLevel, lean_object* opens);
extern lean_object* leanlink_type_check(uint64_t handle, lean_object* exprWXF);
extern lean_object* leanlink_open_goal(uint64_t handle, lean_object* name);
extern lean_object* leanlink_apply_tactic(uint64_t stateId, lean_object* tactic);
extern lean_object* leanlink_open_goal_expr(uint64_t handle, lean_object* exprWXF);
extern lean_object* leanlink_pp_expr(uint64_t handle, lean_object* exprWXF);
extern lean_object* leanlink_evaluate_start(uint64_t handle, lean_object* source, lean_object* expression, lean_object* opens);
extern lean_object* leanlink_evaluate_finished(uint64_t job);
extern lean_object* leanlink_evaluate_cancel(uint64_t job);
extern lean_object* leanlink_evaluate_result(uint64_t job);
extern lean_object* leanlink_evaluate_release(uint64_t handle);

static int g_initialized = 0;
static WolframLibraryData g_libData = NULL;

/* Extract ByteArray from a Lean return value and copy into an MTensor.
   Lean 4.29 ABI: @[export] IO functions return direct values.
   Some return Except-style ctor (tag 0 = ok with inner ByteArray, tag 1 = error),
   others return a raw ByteArray directly.
   We detect the type by checking the object tag:
   - tag 0/1: Except ctor, unwrap the inner value
   - other tags (e.g. sarray): treat as direct ByteArray
   Checks AbortQ() periodically during the byte copy loop. */
static int io_bytearray_to_mtensor(WolframLibraryData libData, lean_object* result, MArgument* Res) {
    /* Guard against NULL result (Lean panic/abort) */
    if (!result) {
        return LIBRARY_FUNCTION_ERROR;
    }

    lean_object* ba;
    lean_object* to_free;
    unsigned tag = lean_obj_tag(result);

    if (tag == 0) {
        /* Except.ok — unwrap inner value */
        lean_object* inner = lean_ctor_get(result, 0);
        if (!inner) {
            lean_dec_ref(result);
            return LIBRARY_FUNCTION_ERROR;
        }
        ba = inner;
        to_free = result;
    } else if (tag == 1) {
        /* Except.error — operation failed */
        lean_dec_ref(result);
        return LIBRARY_FUNCTION_ERROR;
    } else {
        /* Direct value (ByteArray = sarray, tag >= 245) — use as-is */
        ba = result;
        to_free = result;
    }

    /* Verify ba is actually a scalar array before accessing */
    if (!lean_is_sarray(ba)) {
        lean_dec_ref(to_free);
        return LIBRARY_FUNCTION_ERROR;
    }

    size_t n = lean_sarray_size(ba);
    uint8_t* data = lean_sarray_cptr(ba);

    MTensor out;
    mint dims[1] = { (mint)n };
    int err = libData->MTensor_new(MType_Integer, 1, dims, &out);
    if (err) { lean_dec_ref(to_free); return err; }

    mint* buf = libData->MTensor_getIntegerData(out);
    for (size_t i = 0; i < n; i++) {
        buf[i] = (mint)data[i];
        /* Check for user abort every 64K bytes */
        if ((i & 0xFFFF) == 0 && i > 0 && libData->AbortQ()) {
            lean_dec_ref(to_free);
            libData->MTensor_free(out);
            return LIBRARY_FUNCTION_ERROR;
        }
    }
    lean_dec_ref(to_free);
    MArgument_setMTensor(*Res, out);
    return LIBRARY_NO_ERROR;
}

/* ======================================================================== */
/* LibraryLink entry points                                                 */
/* ======================================================================== */

DLLEXPORT mint WolframLibrary_getVersion(void) { return WolframLibraryVersion; }

static int g_lean_initialized = 0;

/* Lazy Lean initialization — called on first API use, not at library load time.
   WolframKernel may kill the process if initialization takes too long during
   WolframLibrary_initialize / LibraryFunctionLoad. */
static int lazy_lean_init(void) {
    if (g_lean_initialized) return LIBRARY_NO_ERROR;

#ifdef LEAN_LIB_DIR
    portable_setenv("LEAN_PATH", LEAN_LIB_DIR, 0);
#endif
    lean_initialize();

    lean_object* res;

    res = initialize_leanlink_LeanLink(1);
    if (lean_io_result_is_error(res)) {
        lean_dec_ref(res);
        return LIBRARY_FUNCTION_ERROR;
    }
    lean_dec_ref(res);

    lean_io_mark_end_initialization();
    lean_init_task_manager();

    res = leanlink_init();
    lean_dec_ref(res);

    g_lean_initialized = 1;
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int WolframLibrary_initialize(WolframLibraryData libData) {
    if (g_initialized) return LIBRARY_NO_ERROR;
    g_libData = libData;
    g_initialized = 1;
    /* Lean init deferred to first API call (lazy_lean_init) */
    return LIBRARY_NO_ERROR;
}

DLLEXPORT void WolframLibrary_uninitialize(WolframLibraryData libData) {
    (void)libData;
}

/*
 * loadEnv(importsStr, searchPathStr) -> handle (Integer)
 */
DLLEXPORT int leanlink_wl_load_env(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();

    /* Lazy-init Lean runtime on first API call */
    int init_err = lazy_lean_init();
    if (init_err) return init_err;

    /* Check abort before expensive operation */
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    const char* imports_cstr = MArgument_getUTF8String(Args[0]);
    const char* path_cstr = MArgument_getUTF8String(Args[1]);

    /* Lean 4.29: importModules reads LEAN_PATH via IO.getEnv internally.
       Without it, module loading panics. Set it from the search path. */
    portable_setenv("LEAN_PATH", path_cstr, 1);

    lean_object* imports = lean_mk_string(imports_cstr);
    lean_object* path = lean_mk_string(path_cstr);

    lean_object* io_res = leanlink_load_env(imports, path);
    /* imports and path consumed by leanlink_load_env */

    if (!io_res) {
        MArgument_setInteger(Res, 0);
        return LIBRARY_FUNCTION_ERROR;
    }

    if (lean_obj_tag(io_res) == 1) {
        /* Except.error */
        lean_dec_ref(io_res);
        MArgument_setInteger(Res, 0);
        return LIBRARY_FUNCTION_ERROR;
    }
    /* tag == 0: Except.ok */
    lean_object* val = lean_ctor_get(io_res, 0);
    uint64_t handle = lean_unbox_uint64(val);
    lean_dec_ref(io_res);
    MArgument_setInteger(Res, (mint)handle);
    return LIBRARY_NO_ERROR;
}

/*
 * freeEnv(handle) -> Null
 */
DLLEXPORT int leanlink_wl_free_env(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    lean_object* io_res = leanlink_free_env(handle);
    lean_dec_ref(io_res);
    return LIBRARY_NO_ERROR;
}

/*
 * listTheorems(handle, filter) -> MTensor (WXF bytes)
 */
DLLEXPORT int leanlink_wl_list_theorems(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* filter_cstr = MArgument_getUTF8String(Args[1]);
    lean_object* filter = lean_mk_string(filter_cstr);

    lean_object* io_res = leanlink_list_theorems(handle, filter);
    /* filter consumed by leanlink_list_theorems */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * listConstantNames(handle, filter) -> MTensor (WXF bytes, names only)
 */
DLLEXPORT int leanlink_wl_list_constant_names(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* filter_cstr = MArgument_getUTF8String(Args[1]);
    lean_object* filter = lean_mk_string(filter_cstr);

    lean_object* io_res = leanlink_list_constant_names(handle, filter);
    /* filter consumed by leanlink_list_constant_names */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * listConstantKinds(handle, filter) -> MTensor (WXF bytes, name->kind assoc)
 */
DLLEXPORT int leanlink_wl_list_constant_kinds(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* filter_cstr = MArgument_getUTF8String(Args[1]);
    lean_object* filter = lean_mk_string(filter_cstr);

    lean_object* io_res = leanlink_list_constant_kinds(handle, filter);
    /* filter consumed by leanlink_list_constant_kinds */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * listConstantKindsSplit(handle, filter, patterns) -> MTensor (WXF bytes,
 * <|"Public" -> name->kind assoc, "Internal" -> name->kind assoc|>, a name internal when it
 * contains one of the patterns, given one per line)
 */
DLLEXPORT int leanlink_wl_list_constant_kinds_split(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    lean_object* filter = lean_mk_string(MArgument_getUTF8String(Args[1]));
    lean_object* patterns = lean_mk_string(MArgument_getUTF8String(Args[2]));

    lean_object* io_res = leanlink_list_constant_kinds_split(handle, filter, patterns);
    /* filter and patterns passed on as leanlink_list_constant_kinds takes its filter */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * getType(handle, name, depth) -> MTensor (WXF bytes)
 */
DLLEXPORT int leanlink_wl_get_type(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    uint32_t depth = (uint32_t)MArgument_getInteger(Args[2]);
    lean_object* name = lean_mk_string(name_cstr);

    lean_object* io_res = leanlink_get_type(handle, name, depth);
    /* name consumed by leanlink_get_type */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * getValue(handle, name, depth) -> MTensor (WXF bytes)
 */
DLLEXPORT int leanlink_wl_get_value(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    uint32_t depth = (uint32_t)MArgument_getInteger(Args[2]);
    lean_object* name = lean_mk_string(name_cstr);

    lean_object* io_res = leanlink_get_value(handle, name, depth);
    /* name consumed by leanlink_get_value */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * getTypeShared(handle, name) -> MTensor (WXF bytes): the type as the table of its
 * distinct subterms, LeanShared[{node, ...}], each subterm Lean shares written once
 */
DLLEXPORT int leanlink_wl_get_type_shared(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    lean_object* name = lean_mk_string(name_cstr);

    lean_object* io_res = leanlink_get_type_shared(handle, name);
    /* name consumed by leanlink_get_type_shared */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * getValueShared(handle, name) -> MTensor (WXF bytes): the value or proof as the table
 * of its distinct subterms
 */
DLLEXPORT int leanlink_wl_get_value_shared(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    lean_object* name = lean_mk_string(name_cstr);

    lean_object* io_res = leanlink_get_value_shared(handle, name);
    /* name consumed by leanlink_get_value_shared */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * getFieldsTable(handle, names) -> MTensor (WXF bytes): the types and values of the
 * constants named, one per line, as one table of their distinct subterms
 */
DLLEXPORT int leanlink_wl_get_fields_table(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* names_cstr = MArgument_getUTF8String(Args[1]);
    lean_object* names = lean_mk_string(names_cstr);
    libData->UTF8String_disown((char*)names_cstr);

    lean_object* io_res = leanlink_get_fields_table(handle, names);
    /* names consumed by leanlink_get_fields_table */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * getBridgeCone(handle, roots) -> MTensor (WXF bytes): the TypeTheory bridge's cone of the
 * constants named, one per line, in the order it declares them, with their kinds and
 * universe parameters
 */
DLLEXPORT int leanlink_wl_get_bridge_cone(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* roots_cstr = MArgument_getUTF8String(Args[1]);
    lean_object* roots = lean_mk_string(roots_cstr);
    libData->UTF8String_disown((char*)roots_cstr);

    lean_object* io_res = leanlink_get_bridge_cone(handle, roots);
    /* roots consumed by leanlink_get_bridge_cone */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * getTypeUnfolded(handle, name, unfoldLevel) -> MTensor (WXF bytes)
 */
DLLEXPORT int leanlink_wl_get_type_unfolded(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    uint32_t unfold_level = (uint32_t)MArgument_getInteger(Args[2]);
    lean_object* name = lean_mk_string(name_cstr);

    lean_object* io_res = leanlink_get_type_unfolded(handle, name, unfold_level);
    /* name consumed by leanlink_get_type_unfolded */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * getValueUnfolded(handle, name, unfoldLevel) -> MTensor (WXF bytes)
 */
DLLEXPORT int leanlink_wl_get_value_unfolded(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    uint32_t unfold_level = (uint32_t)MArgument_getInteger(Args[2]);
    lean_object* name = lean_mk_string(name_cstr);

    lean_object* io_res = leanlink_get_value_unfolded(handle, name, unfold_level);
    /* name consumed by leanlink_get_value_unfolded */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * ppType(handle, name, unfoldLevel) -> MTensor (WXF string)
 */
DLLEXPORT int leanlink_wl_pp_type(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    uint32_t unfold_level = (uint32_t)MArgument_getInteger(Args[2]);
    lean_object* name = lean_mk_string(name_cstr);

    const char* opens_cstr = MArgument_getUTF8String(Args[3]);
    lean_object* opens = lean_mk_string(opens_cstr);
    lean_object* io_res = leanlink_pp_type(handle, name, unfold_level, opens);
    /* name consumed by leanlink_pp_type */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * ppValue(handle, name, unfoldLevel) -> MTensor (WXF string)
 */
DLLEXPORT int leanlink_wl_pp_value(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    uint32_t unfold_level = (uint32_t)MArgument_getInteger(Args[2]);
    lean_object* name = lean_mk_string(name_cstr);

    const char* opens_cstr = MArgument_getUTF8String(Args[3]);
    lean_object* opens = lean_mk_string(opens_cstr);
    lean_object* io_res = leanlink_pp_value(handle, name, unfold_level, opens);
    /* name consumed by leanlink_pp_value */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * typeCheck(handle, exprWXF) -> MTensor (WXF result)
 * exprWXF is an MTensor of integers (the WXF byte array)
 */
DLLEXPORT int leanlink_wl_type_check(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    MTensor wxf_tensor = MArgument_getMTensor(Args[1]);
    mint* wxf_data = libData->MTensor_getIntegerData(wxf_tensor);
    mint wxf_len = libData->MTensor_getFlattenedLength(wxf_tensor);

    /* Build a Lean ByteArray from the MTensor integers */
    lean_object* ba = lean_mk_empty_byte_array(lean_box(wxf_len));
    for (mint i = 0; i < wxf_len; i++) {
        ba = lean_byte_array_push(ba, (uint8_t)(wxf_data[i] & 0xFF));
    }

    lean_object* io_res = leanlink_type_check(handle, ba);
    /* ba is consumed by leanlink_type_check */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * openGoal(handle, constName) -> MTensor (WXF with stateId + goals)
 */
DLLEXPORT int leanlink_wl_open_goal(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name = MArgument_getUTF8String(Args[1]);
    lean_object* lean_name = lean_mk_string(name);

    lean_object* io_res = leanlink_open_goal(handle, lean_name);
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * applyTactic(stateId, tacticStr) -> MTensor (WXF with new stateId + goals)
 */
DLLEXPORT int leanlink_wl_apply_tactic(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t stateId = (uint64_t)MArgument_getInteger(Args[0]);
    const char* tactic = MArgument_getUTF8String(Args[1]);
    lean_object* lean_tactic = lean_mk_string(tactic);

    lean_object* io_res = leanlink_apply_tactic(stateId, lean_tactic);
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * getConstant(handle, name) -> MTensor (WXF bytes)
 */
DLLEXPORT int leanlink_wl_get_constant(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    lean_object* name = lean_mk_string(name_cstr);

    lean_object* io_res = leanlink_get_constant(handle, name);
    /* name consumed by leanlink_get_constant */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * getUsedConstants(handle, name) -> MTensor (WXF bytes)
 * Returns <|"type" -> {names...}, "value" -> {names...}|>
 */
DLLEXPORT int leanlink_wl_module_constant_kinds(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* module_cstr = MArgument_getUTF8String(Args[1]);
    lean_object* module = lean_mk_string(module_cstr);

    lean_object* io_res = leanlink_module_constant_kinds(handle, module);
    /* module consumed by leanlink_module_constant_kinds */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

DLLEXPORT int leanlink_wl_constant_module(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    lean_object* name = lean_mk_string(name_cstr);

    lean_object* io_res = leanlink_constant_module(handle, name);
    /* name consumed by leanlink_constant_module */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

DLLEXPORT int leanlink_wl_decl_range(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    lean_object* name = lean_mk_string(name_cstr);

    lean_object* io_res = leanlink_decl_range(handle, name);
    /* name consumed by leanlink_decl_range */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

DLLEXPORT int leanlink_wl_collect_axioms(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    lean_object* name = lean_mk_string(name_cstr);

    lean_object* io_res = leanlink_collect_axioms(handle, name);
    /* name consumed by leanlink_collect_axioms */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

DLLEXPORT int leanlink_wl_kernel_check(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    lean_object* name = lean_mk_string(name_cstr);

    lean_object* io_res = leanlink_kernel_check(handle, name);
    /* name consumed by leanlink_kernel_check */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

DLLEXPORT int leanlink_wl_get_used_constants(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    lean_object* name = lean_mk_string(name_cstr);

    lean_object* io_res = leanlink_get_used_constants(handle, name);
    /* name consumed by leanlink_get_used_constants */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * ppExpr(handle, exprWXF) -> MTensor (WXF string)
 * Pretty-print an arbitrary WXF-encoded expression via Lean's PrettyPrinter.
 */
DLLEXPORT int leanlink_wl_pp_expr(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;
    if (libData->AbortQ()) return LIBRARY_FUNCTION_ERROR;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    MTensor wxf_tensor = MArgument_getMTensor(Args[1]);
    mint* wxf_data = libData->MTensor_getIntegerData(wxf_tensor);
    mint wxf_len = libData->MTensor_getFlattenedLength(wxf_tensor);

    /* Build a Lean ByteArray from the MTensor integers */
    lean_object* ba = lean_mk_empty_byte_array(lean_box(wxf_len));
    for (mint i = 0; i < wxf_len; i++) {
        ba = lean_byte_array_push(ba, (uint8_t)(wxf_data[i] & 0xFF));
    }

    lean_object* io_res = leanlink_pp_expr(handle, ba);
    /* ba is consumed by leanlink_pp_expr */
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/* ======================================================================== */
/* Evaluation in a loaded environment                                       */
/* ======================================================================== */

/* An evaluation runs on a Lean thread of its own (LeanLink/Evaluate.lean); the kernel starts it, waits for
   it in slices it can abort between, and collects its result. */

/*
 * evaluateStart(handle, source, expression, opens) -> job number, 0 when the handle names no environment
 */
DLLEXPORT int leanlink_wl_evaluate_start(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    int ierr = lazy_lean_init(); if (ierr) return ierr;

    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    char* source_cstr = MArgument_getUTF8String(Args[1]);
    char* expression_cstr = MArgument_getUTF8String(Args[2]);
    char* opens_cstr = MArgument_getUTF8String(Args[3]);
    lean_object* source = lean_mk_string(source_cstr);
    lean_object* expression = lean_mk_string(expression_cstr);
    lean_object* opens = lean_mk_string(opens_cstr);
    libData->UTF8String_disown(source_cstr);
    libData->UTF8String_disown(expression_cstr);
    libData->UTF8String_disown(opens_cstr);

    lean_object* io_res = leanlink_evaluate_start(handle, source, expression, opens);
    /* source, expression and opens consumed by leanlink_evaluate_start */
    if (!io_res || !lean_io_result_is_ok(io_res)) {
        if (io_res) lean_dec_ref(io_res);
        return LIBRARY_FUNCTION_ERROR;
    }
    uint64_t job = lean_unbox_uint64(lean_io_result_get_value(io_res));
    lean_dec_ref(io_res);
    MArgument_setInteger(Res, (mint)job);
    return LIBRARY_NO_ERROR;
}

static int evaluation_finished(uint64_t job) {
    lean_object* io_res = leanlink_evaluate_finished(job);
    int finished = !io_res || !lean_io_result_is_ok(io_res) || lean_unbox(lean_io_result_get_value(io_res)) != 0;
    if (io_res) lean_dec_ref(io_res);
    return finished;
}

/*
 * evaluateWait(job, milliseconds) -> 1 when the evaluation has finished, 0 when it is still running after
 * that long or the kernel was asked to abort. Polls often at first, so a short evaluation is not held up.
 */
DLLEXPORT int leanlink_wl_evaluate_wait(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    uint64_t job = (uint64_t)MArgument_getInteger(Args[0]);
    mint limit_ms = MArgument_getInteger(Args[1]);
    uint64_t deadline = monotonic_us() + (uint64_t)(limit_ms > 0 ? limit_ms : 0) * 1000;
    uint64_t pause = 20;
    int finished;
    while (!(finished = evaluation_finished(job)) && !libData->AbortQ() && monotonic_us() < deadline) {
        sleep_us(pause);
        if (pause < 1000) pause *= 2;
    }
    MArgument_setInteger(Res, finished);
    return LIBRARY_NO_ERROR;
}

/*
 * evaluateCancel(job): asks the evaluation to stop
 */
DLLEXPORT int leanlink_wl_evaluate_cancel(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    lean_object* io_res = leanlink_evaluate_cancel((uint64_t)MArgument_getInteger(Args[0]));
    if (io_res) lean_dec_ref(io_res);
    return LIBRARY_NO_ERROR;
}

/*
 * evaluateResult(job) -> MTensor (WXF): <|"ok" -> True, "value" -> value|> or <|"ok" -> False, "error" -> text|>.
 * Waits for the evaluation when it is still running; call it once evaluateWait has given 1.
 */
DLLEXPORT int leanlink_wl_evaluate_result(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    lean_object* io_res = leanlink_evaluate_result((uint64_t)MArgument_getInteger(Args[0]));
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * evaluateRelease(handle): forgets the state evaluations in that environment start from
 */
DLLEXPORT int leanlink_wl_evaluate_release(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    ensure_thread();
    if (!g_lean_initialized) return LIBRARY_NO_ERROR;
    lean_object* io_res = leanlink_evaluate_release((uint64_t)MArgument_getInteger(Args[0]));
    if (io_res) lean_dec_ref(io_res);
    return LIBRARY_NO_ERROR;
}
