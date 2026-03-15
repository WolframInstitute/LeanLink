// Lean compiler output
// Module: LeanLink.Examples
// Imports: Init
#include <lean/lean.h>
#if defined(__clang__)
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wunused-label"
#elif defined(__GNUC__) && !defined(__CLANG__)
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wunused-label"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#endif
#ifdef __cplusplus
extern "C" {
#endif
LEAN_EXPORT lean_object* l_LeanLink_Examples_Vec_head___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_Examples_Vec_head___rarg(lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_Examples_Vec_map___rarg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_Examples_Vec_head(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_Examples_Vec_head___rarg___boxed(lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_Examples_Vec_map___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_Examples_Vec_map(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_Examples_Vec_head___rarg(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lean_ctor_get(x_1, 1);
lean_inc(x_2);
return x_2;
}
}
LEAN_EXPORT lean_object* l_LeanLink_Examples_Vec_head(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lean_alloc_closure((void*)(l_LeanLink_Examples_Vec_head___rarg___boxed), 1, 0);
return x_3;
}
}
LEAN_EXPORT lean_object* l_LeanLink_Examples_Vec_head___rarg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = l_LeanLink_Examples_Vec_head___rarg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* l_LeanLink_Examples_Vec_head___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = l_LeanLink_Examples_Vec_head(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* l_LeanLink_Examples_Vec_map___rarg(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_2) == 0)
{
lean_object* x_3; 
lean_dec(x_1);
x_3 = lean_box(0);
return x_3;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_2);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; 
x_5 = lean_ctor_get(x_2, 1);
x_6 = lean_ctor_get(x_2, 2);
lean_inc(x_1);
x_7 = lean_apply_1(x_1, x_5);
x_8 = l_LeanLink_Examples_Vec_map___rarg(x_1, x_6);
lean_ctor_set(x_2, 2, x_8);
lean_ctor_set(x_2, 1, x_7);
return x_2;
}
else
{
lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; 
x_9 = lean_ctor_get(x_2, 0);
x_10 = lean_ctor_get(x_2, 1);
x_11 = lean_ctor_get(x_2, 2);
lean_inc(x_11);
lean_inc(x_10);
lean_inc(x_9);
lean_dec(x_2);
lean_inc(x_1);
x_12 = lean_apply_1(x_1, x_10);
x_13 = l_LeanLink_Examples_Vec_map___rarg(x_1, x_11);
x_14 = lean_alloc_ctor(1, 3, 0);
lean_ctor_set(x_14, 0, x_9);
lean_ctor_set(x_14, 1, x_12);
lean_ctor_set(x_14, 2, x_13);
return x_14;
}
}
}
}
LEAN_EXPORT lean_object* l_LeanLink_Examples_Vec_map(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lean_alloc_closure((void*)(l_LeanLink_Examples_Vec_map___rarg), 2, 0);
return x_4;
}
}
LEAN_EXPORT lean_object* l_LeanLink_Examples_Vec_map___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = l_LeanLink_Examples_Vec_map(x_1, x_2, x_3);
lean_dec(x_3);
return x_4;
}
}
lean_object* initialize_Init(uint8_t builtin, lean_object*);
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_LeanLink_Examples(uint8_t builtin, lean_object* w) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
res = initialize_Init(builtin, lean_io_mk_world());
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
