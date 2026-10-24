/*
 * shim_harness.c -- Loads LeanLink's Windows shim without Wolfram, as LeanImport does: it stands in for the
 * LibraryLink callbacks the shim uses, loads an environment, then runs the query that reads a module's
 * constant kinds. test_windows_shim.sh runs it under Wine.
 *
 *     shim_harness <libLeanLinkShim.dll> <imports> <search path> <module>
 *
 * The Lean runtime DLLs must be next to the shim, as the kernel provisions them.
 */

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include "WolframLibrary.h"

typedef struct {
    mint length;
    mint *data;
} harnessTensor;

static mint abortQ(void) {
    return 0;
}

static int tensorNew(mint type, mint rank, const mint *dimensions, MTensor *result) {
    harnessTensor *tensor = malloc(sizeof *tensor);
    tensor->length = dimensions[0];
    tensor->data = calloc(dimensions[0] > 0 ? dimensions[0] : 1, sizeof(mint));
    *result = (MTensor) tensor;
    return LIBRARY_NO_ERROR;
}

static mint *tensorIntegerData(MTensor tensor) {
    return ((harnessTensor *) tensor)->data;
}

static mint tensorLength(MTensor tensor) {
    return ((harnessTensor *) tensor)->length;
}

static void tensorFree(MTensor tensor) {
    free(((harnessTensor *) tensor)->data);
    free(tensor);
}

typedef int (*libraryInitialize)(WolframLibraryData);
typedef int (*libraryFunction)(WolframLibraryData, mint, MArgument *, MArgument);

int main(int argc, char **argv) {
    if (argc < 5) {
        fprintf(stderr, "usage: %s libLeanLinkShim.dll imports searchpath module\n", argv[0]);
        return 2;
    }
    HMODULE shim = LoadLibraryA(argv[1]);
    if (!shim) {
        printf("LoadLibrary failed with error %lu\n", GetLastError());
        return 1;
    }
    printf("shim loaded\n");
    fflush(stdout);

    struct st_WolframLibraryData library = {0};
    library.AbortQ = abortQ;
    library.MTensor_new = tensorNew;
    library.MTensor_getIntegerData = tensorIntegerData;
    library.MTensor_getFlattenedLength = tensorLength;
    library.MTensor_free = tensorFree;

    libraryInitialize initialize = (libraryInitialize) GetProcAddress(shim, "WolframLibrary_initialize");
    libraryFunction loadEnvironment = (libraryFunction) GetProcAddress(shim, "leanlink_wl_load_env");
    libraryFunction moduleConstantKinds = (libraryFunction) GetProcAddress(shim, "leanlink_wl_module_constant_kinds");
    if (!initialize || !loadEnvironment || !moduleConstantKinds) {
        printf("an entry point is missing\n");
        return 1;
    }
    initialize(&library);

    char *imports = argv[2], *searchPath = argv[3], *module = argv[4];
    mint handle = 0;
    MArgument loadArguments[2], loadResult;
    loadArguments[0].utf8string = &imports;
    loadArguments[1].utf8string = &searchPath;
    loadResult.integer = &handle;
    int error = loadEnvironment(&library, 2, loadArguments, loadResult);
    printf("load environment: error %d, handle %lld\n", error, (long long) handle);
    fflush(stdout);
    if (error || handle == 0) {
        return 1;
    }

    MTensor kinds = NULL;
    MArgument kindsArguments[2], kindsResult;
    kindsArguments[0].integer = &handle;
    kindsArguments[1].utf8string = &module;
    kindsResult.tensor = &kinds;
    error = moduleConstantKinds(&library, 2, kindsArguments, kindsResult);
    printf("module constant kinds: error %d, %lld bytes of WXF\n", error, kinds ? (long long) tensorLength(kinds) : -1LL);
    return error;
}
