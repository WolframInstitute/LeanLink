/*
 * test_lean_minimal.c -- Minimal test: skip runtime init, just call module init
 */
#include "lean/lean.h"
#include <stdio.h>
#include <stdlib.h>

extern void lean_initialize_runtime_module(void);
extern void lean_init_task_manager(void);

extern lean_object* initialize_LeanLink(uint8_t builtin, lean_object* w);
extern lean_object* leanlink_init(lean_object* w);
extern lean_object* leanlink_load_env(lean_object* imports, lean_object* searchPath, lean_object* w);

int main(int argc, char** argv) {
    int mode = (argc > 1) ? atoi(argv[1]) : 0;
    printf("=== Lean Minimal Test (mode=%d) ===\n", mode);

    if (mode == 0) {
        printf("Mode 0: NO runtime init, direct initialize_LeanLink(0)\n");
    } else if (mode == 1) {
        printf("Mode 1: runtime_module + task_manager + init(0)\n");
        lean_initialize_runtime_module();
        lean_init_task_manager();
    } else if (mode == 2) {
        printf("Mode 2: runtime_module only + init(0)\n");
        lean_initialize_runtime_module();
    } else if (mode == 3) {
        printf("Mode 3: runtime_module + task_manager + init(1) + loadEnv\n");
        lean_initialize_runtime_module();
        lean_init_task_manager();
    }

    uint8_t builtin = (mode == 3) ? 1 : 0;
    printf("[1] initialize_LeanLink(%d, ...)...\n", builtin);
    lean_object* res = initialize_LeanLink(builtin, lean_io_mk_world());
    if (lean_io_result_is_ok(res)) {
        printf("[1] OK\n");
        lean_dec_ref(res);
    } else {
        printf("[1] FAILED (returned error, not crash)\n");
        lean_dec_ref(res);
        return 1;
    }

    printf("[2] leanlink_init...\n");
    res = leanlink_init(lean_io_mk_world());
    lean_dec_ref(res);
    printf("[2] OK\n");

    if (mode == 3) {
        const char* sp = "/Users/swish/src/wolfram/TuringMachineSearch/Proofs/.lake/build/lib:/Users/swish/.elan/toolchains/leanprover--lean4---v4.15.0/lib/lean";
        printf("[3] leanlink_load_env...\n");
        lean_object* imports = lean_mk_string("OneSidedTM.PlusOne");
        lean_object* path = lean_mk_string(sp);
        res = leanlink_load_env(imports, path, lean_io_mk_world());
        if (lean_io_result_is_ok(res)) {
            printf("[3] loadEnv OK, handle=%llu\n", lean_unbox_uint64(lean_io_result_get_value(res)));
        } else {
            printf("[3] loadEnv returned error\n");
        }
        lean_dec_ref(res);
    }

    printf("=== DONE ===\n");
    return 0;
}
