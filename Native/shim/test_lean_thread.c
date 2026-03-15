/*
 * test_lean_thread.c -- Test Lean init on a thread with large stack
 */
#include "lean/lean.h"
#include <stdio.h>
#include <pthread.h>

extern void lean_initialize_runtime_module(void);
extern void lean_init_task_manager(void);
extern void lean_initialize_thread(void);

extern lean_object* initialize_LeanLink(uint8_t builtin, lean_object* w);
extern lean_object* leanlink_init(lean_object* w);
extern lean_object* leanlink_load_env(lean_object* imports, lean_object* searchPath, lean_object* w);
extern lean_object* leanlink_get_type(uint64_t handle, lean_object* name, uint32_t depth, lean_object* w);

static void* init_thread(void* arg) {
    printf("[T] lean_initialize_thread...\n");
    lean_initialize_thread();

    printf("[T] initialize_LeanLink(1, ...)...\n");
    lean_object* res = initialize_LeanLink(1, lean_io_mk_world());
    if (lean_io_result_is_ok(res)) {
        printf("[T] init OK\n");
        lean_dec_ref(res);
    } else {
        printf("[T] init FAILED\n");
        lean_dec_ref(res);
        return (void*)1;
    }

    printf("[T] leanlink_init...\n");
    res = leanlink_init(lean_io_mk_world());
    lean_dec_ref(res);
    printf("[T] leanlink_init OK\n");

    const char* search_path = "/Users/swish/src/wolfram/TuringMachineSearch/Proofs/.lake/build/lib:/Users/swish/.elan/toolchains/leanprover--lean4---v4.15.0/lib/lean";
    printf("[T] leanlink_load_env...\n");
    lean_object* imports = lean_mk_string("OneSidedTM.PlusOne");
    lean_object* path = lean_mk_string(search_path);
    res = leanlink_load_env(imports, path, lean_io_mk_world());

    if (lean_io_result_is_ok(res)) {
        lean_object* val = lean_io_result_get_value(res);
        uint64_t handle = lean_unbox_uint64(val);
        printf("[T] loadEnv OK, handle = %llu\n", handle);
        lean_dec_ref(res);

        printf("[T] leanlink_get_type...\n");
        lean_object* name = lean_mk_string("OneSidedTM.rule445_computesSucc");
        res = leanlink_get_type(handle, name, 100, lean_io_mk_world());
        if (lean_io_result_is_ok(res)) {
            lean_object* ba = lean_io_result_get_value(res);
            size_t n = lean_sarray_size(ba);
            printf("[T] getType OK, WXF bytes = %zu\n", n);
            lean_dec_ref(res);
        } else {
            printf("[T] getType FAILED\n");
            lean_dec_ref(res);
        }
    } else {
        printf("[T] loadEnv FAILED\n");
        lean_dec_ref(res);
    }

    printf("[T] === ALL DONE ===\n");
    return (void*)0;
}

int main(int argc, char** argv) {
    printf("=== Lean Thread Test (64MB stack) ===\n");

    printf("[M] lean_initialize_runtime_module...\n");
    lean_initialize_runtime_module();
    printf("[M] OK\n");

    printf("[M] lean_init_task_manager...\n");
    lean_init_task_manager();
    printf("[M] OK\n");

    pthread_t tid;
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setstacksize(&attr, 64 * 1024 * 1024); /* 64 MB */

    int rc = pthread_create(&tid, &attr, init_thread, NULL);
    if (rc) { printf("pthread_create failed: %d\n", rc); return 1; }

    void* retval;
    pthread_join(tid, &retval);
    printf("[M] Thread returned: %ld\n", (long)retval);

    return (int)(long)retval;
}
