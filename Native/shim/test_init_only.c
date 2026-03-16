/* Minimal test: just init Lean + our module, no WolframLink needed */
#include <lean/lean.h>
#include <stdio.h>
#include <stdlib.h>

extern lean_object* lean_initialize_runtime_module(void);
extern void lean_io_mark_end_initialization(void);
extern void lean_initialize_thread(void);
extern lean_object* initialize_leanlink_LeanLink(uint8_t builtin);
extern lean_object* leanlink_init(void);
extern lean_object* leanlink_load_env(lean_object* imports, lean_object* searchPath);

int main() {
    fprintf(stderr, "1: runtime init\n"); fflush(stderr);
    lean_object* res = lean_initialize_runtime_module();
    if (lean_io_result_is_error(res)) { fprintf(stderr, "FAIL: runtime\n"); return 1; }
    lean_dec_ref(res);
    
    fprintf(stderr, "2: module init (builtin=1)\n"); fflush(stderr);
    res = initialize_leanlink_LeanLink(1);
    if (lean_io_result_is_error(res)) {
        fprintf(stderr, "FAIL: module init returned error\n");
        lean_dec_ref(res);
        return 1;
    }
    lean_dec_ref(res);
    
    fprintf(stderr, "3: mark end init\n"); fflush(stderr);
    lean_io_mark_end_initialization();
    
    fprintf(stderr, "4: leanlink_init\n"); fflush(stderr);
    res = leanlink_init();
    lean_dec_ref(res);
    
    fprintf(stderr, "5: load env\n"); fflush(stderr);
    lean_object* imports = lean_mk_string("LeanLink");
    lean_object* path = lean_mk_string(
        "/Users/swish/src/wolfram/TuringMachineSearch/Proofs/LeanLink/Native/.lake/build/lib/lean:"
        "/Users/swish/.elan/toolchains/leanprover--lean4---v4.29.0-rc6/lib/lean");
    setenv("LEAN_PATH", lean_string_cstr(path), 1);
    
    lean_object* env_res = leanlink_load_env(imports, path);
    /* imports + path consumed */
    fprintf(stderr, "6: env_res tag=%u\n", lean_obj_tag(env_res)); fflush(stderr);
    if (lean_obj_tag(env_res) == 0) {
        lean_object* val = lean_ctor_get(env_res, 0);
        uint64_t handle = lean_unbox_uint64(val);
        fprintf(stderr, "7: handle=%llu\n", handle);
    } else {
        fprintf(stderr, "7: load_env FAILED\n");
    }
    lean_dec_ref(env_res);
    
    fprintf(stderr, "DONE\n");
    return 0;
}
