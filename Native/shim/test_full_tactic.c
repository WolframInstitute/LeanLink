/* Full test: init, load env, open goal, apply tactics (intro, exact) */
#include <lean/lean.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern lean_object* lean_initialize_runtime_module(void);
extern void lean_io_mark_end_initialization(void);
extern void lean_initialize_thread(void);
extern lean_object* initialize_leanlink_LeanLink(uint8_t builtin);
extern lean_object* leanlink_init(void);
extern lean_object* leanlink_load_env(lean_object* imports, lean_object* searchPath);
extern lean_object* leanlink_open_goal(uint64_t handle, lean_object* name);
extern lean_object* leanlink_apply_tactic(uint64_t stateId, lean_object* tactic);

static void print_bytearray(lean_object* result, const char* label) {
    unsigned tag = lean_obj_tag(result);
    fprintf(stderr, "%s: tag=%u\n", label, tag);
    if (tag == 0) {
        lean_object* ba = lean_ctor_get(result, 0);
        size_t n = lean_sarray_size(ba);
        uint8_t* data = lean_sarray_cptr(ba);
        fprintf(stderr, "  size=%zu, first bytes: ", n);
        for (size_t i = 0; i < n && i < 40; i++) fprintf(stderr, "%02x ", data[i]);
        fprintf(stderr, "\n");
        /* Check for "ERROR" string in the output */
        for (size_t i = 0; i + 5 < n; i++) {
            if (data[i] == 'E' && data[i+1] == 'R' && data[i+2] == 'R' && data[i+3] == 'O' && data[i+4] == 'R') {
                fprintf(stderr, "  CONTAINS ERROR: ...%.*s...\n", (int)(n-i > 80 ? 80 : n-i), data+i);
                break;
            }
        }
    } else {
        fprintf(stderr, "  UNEXPECTED TAG\n");
    }
}

int main() {
    fprintf(stderr, "1: runtime init\n");
    lean_object* res = lean_initialize_runtime_module();
    if (lean_io_result_is_error(res)) { fprintf(stderr, "FAIL: runtime\n"); return 1; }
    lean_dec_ref(res);
    
    fprintf(stderr, "2: module init\n");
    res = initialize_leanlink_LeanLink(1);
    if (lean_io_result_is_error(res)) { fprintf(stderr, "FAIL: module init\n"); lean_dec_ref(res); return 1; }
    lean_dec_ref(res);
    
    lean_io_mark_end_initialization();
    lean_init_task_manager();
    res = leanlink_init();
    lean_dec_ref(res);
    
    fprintf(stderr, "3: load env\n");
    lean_object* imports = lean_mk_string("LeanLink");
    lean_object* path = lean_mk_string(
        "/Users/swish/src/wolfram/TuringMachineSearch/Proofs/LeanLink/Native/.lake/build/lib/lean:"
        "/Users/swish/.elan/toolchains/leanprover--lean4---v4.29.0-rc6/lib/lean");
    setenv("LEAN_PATH",
        "/Users/swish/src/wolfram/TuringMachineSearch/Proofs/LeanLink/Native/.lake/build/lib/lean:"
        "/Users/swish/.elan/toolchains/leanprover--lean4---v4.29.0-rc6/lib/lean", 1);
    
    lean_object* env_res = leanlink_load_env(imports, path);
    if (lean_obj_tag(env_res) != 0) { fprintf(stderr, "FAIL: load_env\n"); return 1; }
    lean_object* val = lean_ctor_get(env_res, 0);
    uint64_t handle = lean_unbox_uint64(val);
    fprintf(stderr, "   handle=%llu\n", handle);
    lean_dec_ref(env_res);
    
    fprintf(stderr, "4: open goal (identity)\n");
    lean_object* goal_name = lean_mk_string("LeanLink.Examples.identity");
    lean_object* goal_res = leanlink_open_goal(handle, goal_name);
    /* goal_name consumed */
    print_bytearray(goal_res, "  openGoal");
    /* Extract stateId from WXF: it's embedded in the ByteArray. For now, assume stateId=1 */
    lean_dec_ref(goal_res);
    
    fprintf(stderr, "5: apply tactic 'intro P'\n");
    lean_object* tac1 = lean_mk_string("intro P");
    lean_object* tac1_res = leanlink_apply_tactic(1, tac1);
    print_bytearray(tac1_res, "  intro P");
    lean_dec_ref(tac1_res);
    
    fprintf(stderr, "6: apply tactic 'intro h'\n");
    lean_object* tac2 = lean_mk_string("intro h");
    lean_object* tac2_res = leanlink_apply_tactic(2, tac2);
    print_bytearray(tac2_res, "  intro h");
    lean_dec_ref(tac2_res);
    
    fprintf(stderr, "7: apply tactic 'exact h'\n");
    lean_object* tac3 = lean_mk_string("exact h");
    lean_object* tac3_res = leanlink_apply_tactic(3, tac3);
    print_bytearray(tac3_res, "  exact h");
    lean_dec_ref(tac3_res);

    /* Test and_comm: constructor tactic */
    fprintf(stderr, "8: open goal (and_comm)\n");
    lean_object* ac_name = lean_mk_string("LeanLink.Examples.and_comm");
    lean_object* ac_res = leanlink_open_goal(handle, ac_name);
    print_bytearray(ac_res, "  and_comm");
    lean_dec_ref(ac_res);
    /* stateId=5 for and_comm */

    fprintf(stderr, "9: intro P Q h\n");
    lean_object* tac4 = lean_mk_string("intro P Q h");
    lean_object* tac4_res = leanlink_apply_tactic(5, tac4);
    print_bytearray(tac4_res, "  intro P Q h");
    lean_dec_ref(tac4_res);
    /* stateId=6 */

    fprintf(stderr, "10: constructor\n");
    lean_object* tac5 = lean_mk_string("constructor");
    lean_object* tac5_res = leanlink_apply_tactic(6, tac5);
    print_bytearray(tac5_res, "  constructor");
    lean_dec_ref(tac5_res);

    fprintf(stderr, "DONE\n");
    return 0;
}
