/*
 * leanlink_shim.c -- Bridges Wolfram LibraryLink and Lean @[export] functions.
 *
 * Compiled together with generated Lean C files into one shared library.
 * Links against libleanshared.dylib (Lean runtime).
 *
 * Lean functions return IO results containing ByteArray (WXF bytes).
 * We extract the raw bytes and return them as a rank-1 MTensor.
 *
 * ABI note: Lean 4.15 keeps the IO world token as the last argument.
 */

#include "WolframLibrary.h"
#include "lean/lean.h"

/* Lean FFI init (not in lean.h but exported from libleanshared) */
extern void lean_initialize(void);

/* Lean module initializer */
extern lean_object* initialize_LeanLink(uint8_t builtin, lean_object* w);

/* Lean @[export] functions (Lean 4.15 ABI: world token as last arg) */
extern lean_object* leanlink_init(lean_object* w);
extern lean_object* leanlink_load_env(lean_object* imports, lean_object* searchPath, lean_object* w);
extern lean_object* leanlink_free_env(uint64_t handle, lean_object* w);
extern lean_object* leanlink_list_theorems(uint64_t handle, lean_object* filter, lean_object* w);
extern lean_object* leanlink_get_type(uint64_t handle, lean_object* name, uint32_t depth, lean_object* w);
extern lean_object* leanlink_get_value(uint64_t handle, lean_object* name, uint32_t depth, lean_object* w);
extern lean_object* leanlink_get_constant(uint64_t handle, lean_object* name, lean_object* w);

static int g_initialized = 0;

/* Extract ByteArray from an IO result and copy into an MTensor */
static int io_bytearray_to_mtensor(WolframLibraryData libData, lean_object* io_res, MArgument* Res) {
    if (!lean_io_result_is_ok(io_res)) {
        lean_dec_ref(io_res);
        return LIBRARY_FUNCTION_ERROR;
    }
    lean_object* ba = lean_io_result_get_value(io_res);
    size_t n = lean_sarray_size(ba);
    uint8_t* data = lean_sarray_cptr(ba);

    MTensor out;
    mint dims[1] = { (mint)n };
    int err = libData->MTensor_new(MType_Integer, 1, dims, &out);
    if (err) { lean_dec_ref(io_res); return err; }

    mint* buf = libData->MTensor_getIntegerData(out);
    for (size_t i = 0; i < n; i++) {
        buf[i] = (mint)data[i];
    }
    lean_dec_ref(io_res);
    MArgument_setMTensor(*Res, out);
    return LIBRARY_NO_ERROR;
}

/* ======================================================================== */
/* LibraryLink entry points                                                 */
/* ======================================================================== */

DLLEXPORT mint WolframLibrary_getVersion(void) { return WolframLibraryVersion; }

DLLEXPORT int WolframLibrary_initialize(WolframLibraryData libData) {
    if (g_initialized) return LIBRARY_NO_ERROR;

    /* Initialize Lean runtime + Init module + task manager */
    lean_initialize();

    /* Initialize our LeanLink module (builtin=1: Init already done above) */
    lean_object* res = initialize_LeanLink(1, lean_io_mk_world());
    if (!lean_io_result_is_ok(res)) {
        lean_dec_ref(res);
        return LIBRARY_FUNCTION_ERROR;
    }
    lean_dec_ref(res);

    /* Call leanlink_init to set up env store */
    res = leanlink_init(lean_io_mk_world());
    lean_dec_ref(res);

    g_initialized = 1;
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
    const char* imports_cstr = MArgument_getUTF8String(Args[0]);
    const char* path_cstr = MArgument_getUTF8String(Args[1]);

    lean_object* imports = lean_mk_string(imports_cstr);
    lean_object* path = lean_mk_string(path_cstr);

    lean_object* io_res = leanlink_load_env(imports, path, lean_io_mk_world());
    lean_dec(imports);
    lean_dec(path);

    if (!lean_io_result_is_ok(io_res)) {
        lean_dec_ref(io_res);
        MArgument_setInteger(Res, 0);
        return LIBRARY_FUNCTION_ERROR;
    }
    lean_object* val = lean_io_result_get_value(io_res);
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
    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    lean_object* io_res = leanlink_free_env(handle, lean_io_mk_world());
    lean_dec_ref(io_res);
    return LIBRARY_NO_ERROR;
}

/*
 * listTheorems(handle, filter) -> MTensor (WXF bytes)
 */
DLLEXPORT int leanlink_wl_list_theorems(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* filter_cstr = MArgument_getUTF8String(Args[1]);
    lean_object* filter = lean_mk_string(filter_cstr);

    lean_object* io_res = leanlink_list_theorems(handle, filter, lean_io_mk_world());
    lean_dec(filter);
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * getType(handle, name, depth) -> MTensor (WXF bytes)
 */
DLLEXPORT int leanlink_wl_get_type(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    uint32_t depth = (uint32_t)MArgument_getInteger(Args[2]);
    lean_object* name = lean_mk_string(name_cstr);

    lean_object* io_res = leanlink_get_type(handle, name, depth, lean_io_mk_world());
    lean_dec(name);
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * getValue(handle, name, depth) -> MTensor (WXF bytes)
 */
DLLEXPORT int leanlink_wl_get_value(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    uint32_t depth = (uint32_t)MArgument_getInteger(Args[2]);
    lean_object* name = lean_mk_string(name_cstr);

    lean_object* io_res = leanlink_get_value(handle, name, depth, lean_io_mk_world());
    lean_dec(name);
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}

/*
 * getConstant(handle, name) -> MTensor (WXF bytes)
 */
DLLEXPORT int leanlink_wl_get_constant(
    WolframLibraryData libData, mint Argc, MArgument* Args, MArgument Res)
{
    uint64_t handle = (uint64_t)MArgument_getInteger(Args[0]);
    const char* name_cstr = MArgument_getUTF8String(Args[1]);
    lean_object* name = lean_mk_string(name_cstr);

    lean_object* io_res = leanlink_get_constant(handle, name, lean_io_mk_world());
    lean_dec(name);
    return io_bytearray_to_mtensor(libData, io_res, &Res);
}
