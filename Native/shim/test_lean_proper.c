/*
 * test_lean_proper.c -- Test with proper Lean FFI init: setup_args + initialize
 */
#include "lean/lean.h"
#include <stdio.h>
#include <stdlib.h>

extern void lean_initialize(void);

extern lean_object* initialize_LeanLink(uint8_t builtin, lean_object* w);
extern lean_object* leanlink_init(lean_object* w);
extern lean_object* leanlink_load_env(lean_object* imports, lean_object* searchPath, lean_object* w);
extern lean_object* leanlink_get_type(uint64_t handle, lean_object* name, uint32_t depth, lean_object* w);

int main(int argc, char** argv) {
    printf("=== Lean Proper Init Test ===\n");

    printf("[1] lean_initialize()...\n");
    lean_initialize();
    printf("[1] OK\n");

    printf("[2] initialize_LeanLink(1, ...)...\n");
    lean_object* res = initialize_LeanLink(1, lean_io_mk_world());
    if (lean_io_result_is_ok(res)) {
        printf("[2] OK\n");
        lean_dec_ref(res);
    } else {
        printf("[2] FAILED\n");
        lean_dec_ref(res);
        return 1;
    }

    printf("[3] leanlink_init...\n");
    res = leanlink_init(lean_io_mk_world());
    lean_dec_ref(res);
    printf("[3] OK\n");

    const char* sp = "/Users/swish/src/wolfram/TuringMachineSearch/Proofs/.lake/build/lib:/Users/swish/.elan/toolchains/leanprover--lean4---v4.15.0/lib/lean";
    printf("[4] leanlink_load_env...\n");
    lean_object* imports = lean_mk_string("OneSidedTM.PlusOne");
    lean_object* path = lean_mk_string(sp);
    res = leanlink_load_env(imports, path, lean_io_mk_world());

    if (lean_io_result_is_ok(res)) {
        lean_object* val = lean_io_result_get_value(res);
        uint64_t handle = lean_unbox_uint64(val);
        printf("[4] loadEnv OK, handle=%llu\n", handle);
        lean_dec_ref(res);

        printf("[5] leanlink_get_type...\n");
        lean_object* name = lean_mk_string("OneSidedTM.rule445_computesSucc");
        res = leanlink_get_type(handle, name, 100, lean_io_mk_world());
        if (lean_io_result_is_ok(res)) {
            lean_object* ba = lean_io_result_get_value(res);
            size_t n = lean_sarray_size(ba);
            printf("[5] getType OK, WXF bytes = %zu\n", n);
            lean_dec_ref(res);
        } else {
            printf("[5] getType FAILED\n");
            lean_dec_ref(res);
        }
    } else {
        printf("[4] loadEnv FAILED (caught by IO)\n");
        lean_dec_ref(res);
    }

    printf("=== ALL DONE ===\n");
    return 0;
}
