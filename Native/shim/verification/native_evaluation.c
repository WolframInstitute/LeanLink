/* Standalone checks of the actual LibraryLink shim, without a Wolfram kernel. */
#include "WolframLibrary.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <windows.h>
static double seconds(void) {
    LARGE_INTEGER counter, frequency;
    QueryPerformanceCounter(&counter);
    QueryPerformanceFrequency(&frequency);
    return (double)counter.QuadPart / (double)frequency.QuadPart;
}
#else
#include <dlfcn.h>
#include <time.h>
static double seconds(void) {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (double)now.tv_sec + (double)now.tv_nsec / 1e9;
}
#endif

typedef struct { mint length; mint *data; } tensor_data;
typedef int (*library_function)(WolframLibraryData, mint, MArgument *, MArgument);
typedef int (*library_initialize)(WolframLibraryData);
static struct st_WolframLibraryData library;
static int abort_requested = 0;
static library_function start_job, wait_job, cancel_job, result_job, release_base, free_env;

static mint abort_q(void) { return abort_requested; }
static void disown_string(char *value) { (void)value; }
static int tensor_new(mint type, mint rank, const mint *dimensions, MTensor *result) {
    if (type != MType_Integer || rank != 1 || dimensions[0] < 0) return LIBRARY_TYPE_ERROR;
    tensor_data *tensor = calloc(1, sizeof(*tensor));
    if (!tensor) return LIBRARY_MEMORY_ERROR;
    tensor->length = dimensions[0];
    tensor->data = calloc(tensor->length ? (size_t)tensor->length : 1, sizeof(mint));
    if (!tensor->data) { free(tensor); return LIBRARY_MEMORY_ERROR; }
    *result = (MTensor)tensor;
    return LIBRARY_NO_ERROR;
}
static mint *tensor_data_ptr(MTensor tensor) { return ((tensor_data *)tensor)->data; }
static mint tensor_length(MTensor tensor) { return ((tensor_data *)tensor)->length; }
static void tensor_free(MTensor tensor) {
    free(((tensor_data *)tensor)->data);
    free(tensor);
}
static void require(int condition, const char *message) {
    if (!condition) { fprintf(stderr, "FAIL: %s\n", message); exit(1); }
}
static mint start(mint handle, char *source, char *expression, char *opens) {
    MArgument args[4], result;
    mint job = 0;
    args[0].integer = &handle;
    args[1].utf8string = &source;
    args[2].utf8string = &expression;
    args[3].utf8string = &opens;
    result.integer = &job;
    require(start_job(&library, 4, args, result) == 0, "evaluate_start returned an error");
    return job;
}
static mint wait_for(mint job, mint limit_ms) {
    MArgument args[2], result;
    mint finished = -1;
    args[0].integer = &job;
    args[1].integer = &limit_ms;
    result.integer = &finished;
    require(wait_job(&library, 2, args, result) == 0, "evaluate_wait returned an error");
    return finished;
}
static void unary(library_function fn, mint value) {
    MArgument argument, result;
    mint unused = 0;
    argument.integer = &value;
    result.integer = &unused;
    require(fn(&library, 1, &argument, result) == 0, "unary operation returned an error");
}
static void collect(mint job, const char *name, double started) {
    double deadline = seconds() + 20;
    while (!wait_for(job, 20)) require(seconds() < deadline, "job did not finish within 20 seconds");
    MArgument argument, result;
    MTensor tensor = NULL;
    argument.integer = &job;
    result.tensor = &tensor;
    require(result_job(&library, 1, &argument, result) == 0 && tensor, "evaluate_result failed");
    double elapsed = seconds() - started;
    printf("RESULT\t%s\t%.9f\t", name, elapsed);
    for (mint i = 0; i < tensor_length(tensor); ++i) printf("%02x", (unsigned)tensor_data_ptr(tensor)[i]);
    printf("\n");
    fflush(stdout);
    tensor_free(tensor);
}
static void evaluate(mint handle, const char *name, char *source, char *expression, char *opens) {
    double started = seconds();
    mint job = start(handle, source, expression, opens);
    require(job != 0, "valid environment produced no job");
    collect(job, name, started);
}

int main(int argc, char **argv) {
    require(argc == 4, "usage: native_evaluation shim imports searchpath");
#ifdef _WIN32
    HMODULE shim = LoadLibraryExA(argv[1], NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    if (!shim) fprintf(stderr, "LoadLibrary error: %lu\n", GetLastError());
    require(shim != NULL, "could not load shim");
#define SYMBOL(name) GetProcAddress(shim, name)
#else
    void *shim = dlopen(argv[1], RTLD_NOW | RTLD_GLOBAL);
    if (!shim) fprintf(stderr, "%s\n", dlerror());
    require(shim != NULL, "could not load shim");
#define SYMBOL(name) dlsym(shim, name)
#endif
    library_initialize initialize = (library_initialize)SYMBOL("WolframLibrary_initialize");
    library_function load = (library_function)SYMBOL("leanlink_wl_load_env");
    start_job = (library_function)SYMBOL("leanlink_wl_evaluate_start");
    wait_job = (library_function)SYMBOL("leanlink_wl_evaluate_wait");
    cancel_job = (library_function)SYMBOL("leanlink_wl_evaluate_cancel");
    result_job = (library_function)SYMBOL("leanlink_wl_evaluate_result");
    release_base = (library_function)SYMBOL("leanlink_wl_evaluate_release");
    free_env = (library_function)SYMBOL("leanlink_wl_free_env");
    require(initialize && load && start_job && wait_job && cancel_job && result_job && release_base && free_env,
            "missing exported function");
    library.AbortQ = abort_q;
    library.UTF8String_disown = disown_string;
    library.MTensor_new = tensor_new;
    library.MTensor_getIntegerData = tensor_data_ptr;
    library.MTensor_getFlattenedLength = tensor_length;
    library.MTensor_free = tensor_free;
    require(initialize(&library) == 0, "library initialization failed");
    MArgument args[2], result;
    mint handle = 0;
    args[0].utf8string = &argv[2];
    args[1].utf8string = &argv[3];
    result.integer = &handle;
    double started = seconds();
    require(load(&library, 2, args, result) == 0 && handle, "environment import failed");
    printf("IMPORT\t%.9f\n", seconds() - started);
    fflush(stdout);

    evaluate(handle, "first", "", "2^100", "");
    for (int n = 0; n < 7; ++n) evaluate(handle, "repeated", "", "2^100", "");
    evaluate(handle, "prepare", "", "", "");
    evaluate(handle, "source-one", "def localValue := 42", "localValue", "");
    evaluate(handle, "source-two", "def localValue := 7", "localValue", "");
    evaluate(handle, "source-not-leaked", "", "localValue", "");
    evaluate(handle, "recovery", "", "6*7", "");
    evaluate(handle, "namespace", "namespace Demo\ndef answer := 42\nend Demo", "answer", "Demo");
    evaluate(handle, "unicode", "", "\"α世🙂\\n\\\"\\\\\"", "");
    evaluate(handle, "list", "", "List.range 20000", "");
    if (strstr(argv[2], "Mathlib")) {
        evaluate(handle, "choose-first", "", "Nat.choose 50 25", "");
        for (int n = 0; n < 7; ++n) evaluate(handle, "choose-repeated", "", "Nat.choose 50 25", "");
        evaluate(handle, "sqrt", "", "Nat.sqrt 123456789", "");
    }

    mint job = start(handle, "#eval (IO.sleep 500 : IO Unit)", "42", "");
    started = seconds();
    mint finished = wait_for(job, 20);
    double waited = seconds() - started;
    require(!finished && waited < 0.3, "wait deadline was not observed");
    printf("CHECK\twait-deadline\t%.9f\n", waited);
    abort_requested = 1;
    started = seconds();
    finished = wait_for(job, 1000);
    waited = seconds() - started;
    abort_requested = 0;
    require(!finished && waited < 0.1, "abort callback was not observed");
    printf("CHECK\tabort-wait\t%.9f\n", waited);
    unary(cancel_job, job);
    collect(job, "cancelled", seconds());
    evaluate(handle, "after-cancel", "", "42", "");
    unary(release_base, handle);
    evaluate(handle, "after-release", "", "42", "");
    unary(free_env, handle);
    require(start(handle, "", "42", "") == 0, "released environment still accepts work");
    printf("CHECK\treleased-environment\t0\n");
    return 0;
}
