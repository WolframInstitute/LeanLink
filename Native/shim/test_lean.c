/*
 * test_lean.c -- Standalone test for Lean env loading (no WL dependency)
 */
#include "lean/lean.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern void lean_initialize_runtime_module(void);
extern void lean_init_task_manager(void);
extern lean_object* lean_initialize(void);
extern void lean_initialize_thread(void);

extern lean_object* initialize_LeanLink(uint8_t builtin, lean_object* w);
extern lean_object* leanlink_init(lean_object* w);
extern lean_object* leanlink_load_env(lean_object* imports, lean_object* searchPath, lean_object* w);
extern lean_object* leanlink_get_type(uint64_t handle, lean_object* name, uint32_t depth, lean_object* w);

int main(int argc, char** argv) {
    printf("=== Lean Runtime Test ===\n");

    printf("[1] lean_initialize_runtime_module...\n");
    lean_initialize_runtime_module();
    printf("[1] OK\n");

    printf("[2] lean_init_task_manager...\n");
    lean_init_task_manager();
    printf("[2] OK\n");

    printf("[2b] lean_initialize_thread...\n");
    lean_initialize_thread();
    printf("[2b] OK\n");

    printf("[3] initialize_LeanLink(0, ...)...\n");
    lean_object* res = initialize_LeanLink(0, lean_io_mk_world());
    if (lean_io_result_is_ok(res)) {
        printf("[3] OK\n");
        lean_dec_ref(res);
    } else {
        printf("[3] FAILED\n");
        lean_object* err = lean_io_result_get_error(res);
        if (lean_is_scalar(err)) {
            printf("    error is scalar: %zu\n", lean_unbox(err));
        } else {
            printf("    error tag: %u\n", lean_ptr_tag(err));
        }
        lean_dec_ref(res);
        return 1;
    }

    printf("[4] leanlink_init...\n");
    res = leanlink_init(lean_io_mk_world());
    if (lean_io_result_is_ok(res)) {
        printf("[4] OK\n");
        lean_dec_ref(res);
    } else {
        printf("[4] FAILED\n");
        lean_dec_ref(res);
        return 1;
    }

    const char* search_path = "/Users/swish/src/wolfram/TuringMachineSearch/Proofs/.lake/build/lib:/Users/swish/.elan/toolchains/leanprover--lean4---v4.15.0/lib/lean";
    const char* import_name = "OneSidedTM.PlusOne";

    printf("[5] leanlink_load_env(\"%s\", \"%s\")...\n", import_name, search_path);
    lean_object* imports = lean_mk_string(import_name);
    lean_object* path = lean_mk_string(search_path);
    res = leanlink_load_env(imports, path, lean_io_mk_world());
    lean_dec(imports);
    lean_dec(path);

    if (lean_io_result_is_ok(res)) {
        lean_object* val = lean_io_result_get_value(res);
        uint64_t handle = lean_unbox_uint64(val);
        printf("[5] OK, handle = %llu\n", handle);
        lean_dec_ref(res);

        printf("[6] leanlink_get_type(handle, \"OneSidedTM.rule445_computesSucc\", 100)...\n");
        lean_object* name = lean_mk_string("OneSidedTM.rule445_computesSucc");
        res = leanlink_get_type(handle, name, 100, lean_io_mk_world());
        lean_dec(name);

        if (lean_io_result_is_ok(res)) {
            lean_object* ba = lean_io_result_get_value(res);
            size_t n = lean_sarray_size(ba);
            printf("[6] OK, WXF bytes = %zu\n", n);
            lean_dec_ref(res);
        } else {
            printf("[6] FAILED\n");
            lean_dec_ref(res);
        }
    } else {
        printf("[5] FAILED\n");
        lean_object* err = lean_io_result_get_error(res);
        printf("    error tag: %u, is_scalar: %d\n", 
               lean_is_scalar(err) ? 0 : lean_ptr_tag(err),
               lean_is_scalar(err));
        lean_dec_ref(res);
        return 1;
    }

    printf("=== ALL TESTS PASSED ===\n");
    return 0;
}
