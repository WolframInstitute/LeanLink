// Lean compiler output
// Module: LeanLink.EnvStore
// Imports: Init Lean LeanLink.WXF
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
LEAN_EXPORT uint8_t l_LeanLink_listTheoremsExport___lambda__1(lean_object*);
LEAN_EXPORT lean_object* l_Array_foldlMUnsafe_fold___at_LeanLink_loadEnvExport___spec__7___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
lean_object* lean_string_utf8_extract(lean_object*, lean_object*, lean_object*);
lean_object* l_WXF_wlAssociation(lean_object*);
static lean_object* l_LeanLink_loadEnvExport___closed__2;
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_foldlM___at_LeanLink_loadEnvExport___spec__4(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_listConstantNamesExport___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_getUsedConstantsExport___boxed(lean_object*, lean_object*, lean_object*);
static lean_object* l_LeanLink_getUsedConstantsExport___closed__3;
lean_object* lean_uint32_to_nat(uint32_t);
LEAN_EXPORT lean_object* leanlink_get_constant(uint64_t, lean_object*, lean_object*);
lean_object* l_Lean_ConstantInfo_type(lean_object*);
LEAN_EXPORT lean_object* l_Array_foldlMUnsafe_fold___at_LeanLink_getUsedConstantsExport___spec__3(lean_object*, size_t, size_t, lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_48_(lean_object*);
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(uint64_t, lean_object*);
LEAN_EXPORT lean_object* leanlink_get_value(uint64_t, lean_object*, uint32_t, lean_object*);
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_erase___at_LeanLink_freeEnvExport___spec__1___boxed(lean_object*, lean_object*);
size_t lean_uint64_to_usize(uint64_t);
lean_object* l_Lean_Name_toString(lean_object*, uint8_t, lean_object*);
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__5___rarg___boxed(lean_object*, lean_object*, lean_object*);
lean_object* lean_array_push(lean_object*, lean_object*);
static lean_object* l_LeanLink_loadEnv___closed__7;
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_contains___at_LeanLink_loadEnvExport___spec__1___boxed(lean_object*, lean_object*);
static lean_object* l_LeanLink_listTheoremsExport___closed__2;
LEAN_EXPORT lean_object* l_Lean_SMap_fold___at_LeanLink_listTheoremsExport___spec__2(lean_object*);
lean_object* lean_mk_array(lean_object*, lean_object*);
static lean_object* l_LeanLink_loadEnv___closed__5;
uint8_t lean_usize_dec_eq(size_t, size_t);
uint8_t l_Lean_NameHashSet_contains(lean_object*, lean_object*);
lean_object* l_Lean_ConstantInfo_getUsedConstantsAsSet(lean_object*);
LEAN_EXPORT lean_object* l_Array_mapMUnsafe_map___at_LeanLink_loadEnv___spec__2(size_t, size_t, lean_object*);
static lean_object* l_LeanLink_loadEnv___closed__4;
lean_object* lean_array_fget(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__5(lean_object*);
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_Raw_u2080_expand_go___at_LeanLink_loadEnvExport___spec__3(lean_object*, lean_object*, lean_object*);
lean_object* lean_array_fset(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_foldlM___at_LeanLink_listTheoremsExport___spec__3(lean_object*);
lean_object* lean_io_getenv(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5_(lean_object*);
lean_object* lean_environment_find(lean_object*, lean_object*);
lean_object* l_Nat_nextPowerOfTwo_go(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_initLeanLink___boxed__const__1;
LEAN_EXPORT lean_object* l_Array_mapMUnsafe_map___at_LeanLink_getUsedConstantsExport___spec__1___boxed(lean_object*, lean_object*, lean_object*);
uint8_t lean_string_dec_eq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* leanlink_free_env(uint64_t, lean_object*);
lean_object* l_ByteArray_append(lean_object*, lean_object*);
lean_object* lean_string_utf8_byte_size(lean_object*);
lean_object* l_Lean_ConstantInfo_value_x3f(lean_object*);
LEAN_EXPORT lean_object* l___private_LeanLink_EnvStore_0__LeanLink_nextHandle;
LEAN_EXPORT lean_object* l_LeanLink_freeEnvExport___boxed(lean_object*, lean_object*);
lean_object* l_WXF_string(lean_object*);
static lean_object* l_LeanLink_listTheoremsExport___lambda__2___closed__1;
lean_object* l_List_appendTR___rarg(lean_object*, lean_object*);
size_t lean_usize_of_nat(lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_listTheoremsExport___lambda__1___boxed(lean_object*);
uint8_t l_instDecidableNot___rarg(uint8_t);
lean_object* lean_st_ref_take(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lean_SMap_fold___at_LeanLink_listTheoremsExport___spec__2___rarg(lean_object*, lean_object*, lean_object*);
lean_object* l_WXF_constantToWXF(lean_object*);
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__7(lean_object*);
lean_object* l_String_splitOnAux(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
static uint8_t l_LeanLink_loadEnvExport___closed__5;
uint64_t lean_uint64_shift_right(uint64_t, uint64_t);
LEAN_EXPORT lean_object* l_LeanLink_listTheoremsExport___boxed(lean_object*, lean_object*, lean_object*);
lean_object* l_IO_eprintln___at___private_Init_System_IO_0__IO_eprintlnAux___spec__1(lean_object*, lean_object*);
lean_object* l_WXF_constantKind(lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_listConstantKindsExport___lambda__1___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
lean_object* lean_nat_div(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_foldlM___at_LeanLink_loadEnvExport___spec__4___at_LeanLink_loadEnvExport___spec__5(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_loadEnv(lean_object*, lean_object*, lean_object*);
static lean_object* l_LeanLink_loadEnvExport___closed__1;
LEAN_EXPORT lean_object* l_Array_foldlMUnsafe_fold___at_LeanLink_listTheoremsExport___spec__6___rarg___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
lean_object* lean_st_ref_get(lean_object*, lean_object*);
lean_object* l_Lean_PersistentHashMap_foldlMAux___at_Lean_MetavarContext_getExprAssignmentDomain___spec__2___rarg(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_Raw_u2080_expand___at_LeanLink_loadEnvExport___spec__2(lean_object*);
lean_object* lean_st_mk_ref(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_replace___at_LeanLink_loadEnvExport___spec__6___boxed(lean_object*, lean_object*, lean_object*);
uint64_t lean_uint64_add(uint64_t, uint64_t);
static lean_object* l_LeanLink_loadEnvExport___closed__4;
LEAN_EXPORT lean_object* l_LeanLink_loadEnvExport___boxed__const__1;
LEAN_EXPORT uint8_t l_Std_DHashMap_Internal_AssocList_contains___at_LeanLink_loadEnvExport___spec__1(uint64_t, lean_object*);
LEAN_EXPORT lean_object* l_Array_mapMUnsafe_map___at_LeanLink_getUsedConstantsExport___spec__1(size_t, size_t, lean_object*);
LEAN_EXPORT lean_object* l_Lean_SMap_fold___at_LeanLink_listTheoremsExport___spec__2___rarg___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_listTheoremsExport___lambda__2(lean_object*, lean_object*, lean_object*, lean_object*);
lean_object* l_List_lengthTRAux___rarg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Array_foldlMUnsafe_fold___at_LeanLink_loadEnvExport___spec__7(lean_object*, size_t, size_t, lean_object*);
static lean_object* l_LeanLink_loadEnv___closed__6;
LEAN_EXPORT lean_object* leanlink_load_env(lean_object*, lean_object*, lean_object*);
extern lean_object* l_WXF_header;
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_replace___at_LeanLink_loadEnvExport___spec__6(uint64_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* leanlink_get_used_constants(uint64_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__4(lean_object*);
LEAN_EXPORT lean_object* leanlink_list_constant_names(uint64_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1(lean_object*, lean_object*);
lean_object* l_Array_append___rarg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lean_RBNode_fold___at_LeanLink_getUsedConstantsExport___spec__2(lean_object*, lean_object*, lean_object*, lean_object*);
static lean_object* l_LeanLink_listTheoremsExport___closed__1;
lean_object* l_Substring_takeWhileAux___at_Substring_trimLeft___spec__1(lean_object*, lean_object*, lean_object*);
static lean_object* l_LeanLink_listTheoremsExport___closed__3;
LEAN_EXPORT lean_object* leanlink_list_constant_kinds(uint64_t, lean_object*, lean_object*);
static lean_object* l_LeanLink_getUsedConstantsExport___closed__4;
LEAN_EXPORT lean_object* leanlink_get_type(uint64_t, lean_object*, uint32_t, lean_object*);
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_foldlM___at_LeanLink_listTheoremsExport___spec__3___rarg(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_listConstantKindsExport___boxed(lean_object*, lean_object*, lean_object*);
static lean_object* l_LeanLink_loadEnvExport___closed__3;
static lean_object* l_LeanLink_loadEnv___closed__1;
uint8_t lean_nat_dec_lt(lean_object*, lean_object*);
lean_object* l_Substring_takeRightWhileAux___at_Substring_trimRight___spec__1(lean_object*, lean_object*, lean_object*);
extern lean_object* l_Lean_searchPathRef;
LEAN_EXPORT lean_object* leanlink_init(lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_getConstantExport___boxed(lean_object*, lean_object*, lean_object*);
static uint8_t l_LeanLink_loadEnv___closed__2;
LEAN_EXPORT lean_object* l___private_LeanLink_EnvStore_0__LeanLink_envStore;
lean_object* l_String_toName(lean_object*);
uint64_t lean_uint64_xor(uint64_t, uint64_t);
static lean_object* l_LeanLink_getUsedConstantsExport___closed__1;
lean_object* lean_nat_sub(lean_object*, lean_object*);
static lean_object* l_LeanLink_getUsedConstantsExport___closed__2;
lean_object* lean_nat_mul(lean_object*, lean_object*);
static lean_object* l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__2;
lean_object* l_WXF_exprToWXF(lean_object*, lean_object*);
lean_object* l_Lean_NameHashSet_insert(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Array_mapMUnsafe_map___at_LeanLink_loadEnv___spec__2___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Array_foldlMUnsafe_fold___at_LeanLink_listTheoremsExport___spec__6(lean_object*);
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__4___rarg___boxed(lean_object*, lean_object*, lean_object*);
lean_object* l_List_reverse___rarg(lean_object*);
uint8_t lean_uint64_dec_eq(uint64_t, uint64_t);
LEAN_EXPORT lean_object* l_LeanLink_listConstantNamesExport___lambda__1___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
static lean_object* l_LeanLink_getValueExport___closed__1;
size_t lean_usize_sub(size_t, size_t);
lean_object* lean_array_mk(lean_object*);
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_erase___at_LeanLink_freeEnvExport___spec__1(uint64_t, lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_initFn___boxed__const__1____x40_LeanLink_EnvStore___hyg_48_;
LEAN_EXPORT lean_object* l_LeanLink_getValueExport___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__7___rarg___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_getTypeExport___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__5___rarg(lean_object*, lean_object*, lean_object*);
size_t lean_usize_add(size_t, size_t);
static lean_object* l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
LEAN_EXPORT lean_object* l_LeanLink_listTheoremsExport___lambda__2___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
lean_object* lean_array_uget(lean_object*, size_t);
size_t lean_array_size(lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_listConstantNamesExport___lambda__1(lean_object*, lean_object*, lean_object*, lean_object*);
lean_object* lean_io_error_to_string(lean_object*);
lean_object* lean_st_ref_set(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* leanlink_list_theorems(uint64_t, lean_object*, lean_object*);
lean_object* l_List_mapTR_loop___at_System_SearchPath_parse___spec__3(lean_object*, lean_object*);
static lean_object* l_LeanLink_loadEnv___closed__3;
lean_object* lean_string_append(lean_object*, lean_object*);
lean_object* lean_array_get_size(lean_object*);
LEAN_EXPORT lean_object* l_Array_foldlMUnsafe_fold___at_LeanLink_getUsedConstantsExport___spec__3___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
lean_object* l_Lean_Expr_getUsedConstants(lean_object*);
LEAN_EXPORT lean_object* l_LeanLink_listConstantKindsExport___lambda__1(lean_object*, lean_object*, lean_object*, lean_object*);
uint8_t lean_nat_dec_le(lean_object*, lean_object*);
uint8_t lean_usize_dec_lt(size_t, size_t);
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__4___rarg(lean_object*, lean_object*, lean_object*);
lean_object* lean_nat_add(lean_object*, lean_object*);
static lean_object* l_LeanLink_getTypeExport___closed__1;
static lean_object* l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3;
lean_object* lean_import_modules(lean_object*, lean_object*, uint32_t, uint8_t, lean_object*);
lean_object* l_WXF_wlList(lean_object*);
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__7___rarg(lean_object*, lean_object*, lean_object*);
static lean_object* l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__1;
static lean_object* l_LeanLink_loadEnvExport___closed__6;
lean_object* lean_array_uset(lean_object*, size_t, lean_object*);
LEAN_EXPORT lean_object* l_Lean_RBNode_fold___at_LeanLink_getUsedConstantsExport___spec__2___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Array_foldlMUnsafe_fold___at_LeanLink_listTheoremsExport___spec__6___rarg(lean_object*, lean_object*, size_t, size_t, lean_object*);
size_t lean_usize_land(size_t, size_t);
static lean_object* _init_l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__1() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = lean_unsigned_to_nat(10u);
x_2 = lean_unsigned_to_nat(1u);
x_3 = l_Nat_nextPowerOfTwo_go(x_1, x_2, lean_box(0));
return x_3;
}
}
static lean_object* _init_l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = lean_box(0);
x_2 = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__1;
x_3 = lean_mk_array(x_2, x_1);
return x_3;
}
}
static lean_object* _init_l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = lean_unsigned_to_nat(0u);
x_2 = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__2;
x_3 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_3, 0, x_1);
lean_ctor_set(x_3, 1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5_(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; uint8_t x_4; 
x_2 = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3;
x_3 = lean_st_mk_ref(x_2, x_1);
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
return x_3;
}
else
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_6);
lean_inc(x_5);
lean_dec(x_3);
x_7 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_7, 0, x_5);
lean_ctor_set(x_7, 1, x_6);
return x_7;
}
}
}
static lean_object* _init_l_LeanLink_initFn___boxed__const__1____x40_LeanLink_EnvStore___hyg_48_() {
_start:
{
uint64_t x_1; lean_object* x_2; 
x_1 = 1;
x_2 = lean_box_uint64(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_48_(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; uint8_t x_4; 
x_2 = l_LeanLink_initFn___boxed__const__1____x40_LeanLink_EnvStore___hyg_48_;
x_3 = lean_st_mk_ref(x_2, x_1);
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
return x_3;
}
else
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_6);
lean_inc(x_5);
lean_dec(x_3);
x_7 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_7, 0, x_5);
lean_ctor_set(x_7, 1, x_6);
return x_7;
}
}
}
static lean_object* _init_l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("", 0, 0);
return x_1;
}
}
LEAN_EXPORT lean_object* l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
x_3 = l_List_reverse___rarg(x_2);
return x_3;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_1);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; uint8_t x_8; uint8_t x_9; 
x_5 = lean_ctor_get(x_1, 0);
x_6 = lean_ctor_get(x_1, 1);
x_7 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_8 = lean_string_dec_eq(x_5, x_7);
x_9 = l_instDecidableNot___rarg(x_8);
if (x_9 == 0)
{
lean_free_object(x_1);
lean_dec(x_5);
x_1 = x_6;
goto _start;
}
else
{
lean_ctor_set(x_1, 1, x_2);
{
lean_object* _tmp_0 = x_6;
lean_object* _tmp_1 = x_1;
x_1 = _tmp_0;
x_2 = _tmp_1;
}
goto _start;
}
}
else
{
lean_object* x_12; lean_object* x_13; lean_object* x_14; uint8_t x_15; uint8_t x_16; 
x_12 = lean_ctor_get(x_1, 0);
x_13 = lean_ctor_get(x_1, 1);
lean_inc(x_13);
lean_inc(x_12);
lean_dec(x_1);
x_14 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_15 = lean_string_dec_eq(x_12, x_14);
x_16 = l_instDecidableNot___rarg(x_15);
if (x_16 == 0)
{
lean_dec(x_12);
x_1 = x_13;
goto _start;
}
else
{
lean_object* x_18; 
x_18 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_18, 0, x_12);
lean_ctor_set(x_18, 1, x_2);
x_1 = x_13;
x_2 = x_18;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* l_Array_mapMUnsafe_map___at_LeanLink_loadEnv___spec__2(size_t x_1, size_t x_2, lean_object* x_3) {
_start:
{
uint8_t x_4; 
x_4 = lean_usize_dec_lt(x_2, x_1);
if (x_4 == 0)
{
return x_3;
}
else
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; uint8_t x_9; lean_object* x_10; size_t x_11; size_t x_12; lean_object* x_13; 
x_5 = lean_array_uget(x_3, x_2);
x_6 = lean_unsigned_to_nat(0u);
x_7 = lean_array_uset(x_3, x_2, x_6);
x_8 = l_String_toName(x_5);
x_9 = 0;
x_10 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_10, 0, x_8);
lean_ctor_set_uint8(x_10, sizeof(void*)*1, x_9);
x_11 = 1;
x_12 = lean_usize_add(x_2, x_11);
x_13 = lean_array_uset(x_7, x_2, x_10);
x_2 = x_12;
x_3 = x_13;
goto _start;
}
}
}
static lean_object* _init_l_LeanLink_loadEnv___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked(":", 1, 1);
return x_1;
}
}
static uint8_t _init_l_LeanLink_loadEnv___closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; uint8_t x_3; 
x_1 = l_LeanLink_loadEnv___closed__1;
x_2 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_3 = lean_string_dec_eq(x_1, x_2);
return x_3;
}
}
static lean_object* _init_l_LeanLink_loadEnv___closed__3() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("LEAN_SYSROOT", 12, 12);
return x_1;
}
}
static lean_object* _init_l_LeanLink_loadEnv___closed__4() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("LEAN_PATH", 9, 9);
return x_1;
}
}
static lean_object* _init_l_LeanLink_loadEnv___closed__5() {
_start:
{
lean_object* x_1; 
x_1 = l_Lean_searchPathRef;
return x_1;
}
}
static lean_object* _init_l_LeanLink_loadEnv___closed__6() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("/lib/lean/library", 17, 17);
return x_1;
}
}
static lean_object* _init_l_LeanLink_loadEnv___closed__7() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("/lib/lean", 9, 9);
return x_1;
}
}
LEAN_EXPORT lean_object* l_LeanLink_loadEnv(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; uint8_t x_137; 
x_4 = lean_box(0);
x_5 = l_LeanLink_loadEnv___closed__3;
x_6 = lean_io_getenv(x_5, x_3);
x_137 = l_LeanLink_loadEnv___closed__2;
if (x_137 == 0)
{
lean_object* x_138; lean_object* x_139; lean_object* x_140; 
x_138 = l_LeanLink_loadEnv___closed__1;
x_139 = lean_unsigned_to_nat(0u);
x_140 = l_String_splitOnAux(x_2, x_138, x_139, x_139, x_139, x_4);
lean_dec(x_2);
x_7 = x_140;
goto block_136;
}
else
{
lean_object* x_141; 
x_141 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_141, 0, x_2);
lean_ctor_set(x_141, 1, x_4);
x_7 = x_141;
goto block_136;
}
block_136:
{
uint8_t x_8; 
x_8 = !lean_is_exclusive(x_6);
if (x_8 == 0)
{
lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; uint8_t x_15; 
x_9 = lean_ctor_get(x_6, 0);
x_10 = lean_ctor_get(x_6, 1);
x_11 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1(x_7, x_4);
x_12 = l_List_mapTR_loop___at_System_SearchPath_parse___spec__3(x_11, x_4);
x_13 = l_LeanLink_loadEnv___closed__4;
x_14 = lean_io_getenv(x_13, x_10);
x_15 = !lean_is_exclusive(x_14);
if (x_15 == 0)
{
lean_object* x_16; lean_object* x_17; lean_object* x_18; 
x_16 = lean_ctor_get(x_14, 0);
x_17 = lean_ctor_get(x_14, 1);
if (lean_obj_tag(x_9) == 0)
{
lean_free_object(x_6);
if (lean_obj_tag(x_16) == 0)
{
lean_free_object(x_14);
x_18 = x_4;
goto block_37;
}
else
{
lean_object* x_38; uint8_t x_39; 
x_38 = lean_ctor_get(x_16, 0);
lean_inc(x_38);
lean_dec(x_16);
x_39 = l_LeanLink_loadEnv___closed__2;
if (x_39 == 0)
{
lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; 
lean_free_object(x_14);
x_40 = l_LeanLink_loadEnv___closed__1;
x_41 = lean_unsigned_to_nat(0u);
x_42 = l_String_splitOnAux(x_38, x_40, x_41, x_41, x_41, x_4);
lean_dec(x_38);
x_43 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1(x_42, x_4);
x_44 = l_List_mapTR_loop___at_System_SearchPath_parse___spec__3(x_43, x_4);
x_18 = x_44;
goto block_37;
}
else
{
lean_object* x_45; lean_object* x_46; 
lean_ctor_set_tag(x_14, 1);
lean_ctor_set(x_14, 1, x_4);
lean_ctor_set(x_14, 0, x_38);
x_45 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1(x_14, x_4);
x_46 = l_List_mapTR_loop___at_System_SearchPath_parse___spec__3(x_45, x_4);
x_18 = x_46;
goto block_37;
}
}
}
else
{
lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; lean_object* x_51; 
lean_dec(x_16);
x_47 = lean_ctor_get(x_9, 0);
lean_inc(x_47);
lean_dec(x_9);
x_48 = l_LeanLink_loadEnv___closed__6;
lean_inc(x_47);
x_49 = lean_string_append(x_47, x_48);
x_50 = l_LeanLink_loadEnv___closed__7;
x_51 = lean_string_append(x_47, x_50);
lean_ctor_set_tag(x_14, 1);
lean_ctor_set(x_14, 1, x_4);
lean_ctor_set(x_14, 0, x_51);
lean_ctor_set_tag(x_6, 1);
lean_ctor_set(x_6, 1, x_14);
lean_ctor_set(x_6, 0, x_49);
x_18 = x_6;
goto block_37;
}
block_37:
{
lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; size_t x_23; size_t x_24; lean_object* x_25; uint32_t x_26; uint8_t x_27; lean_object* x_28; 
x_19 = l_List_appendTR___rarg(x_12, x_18);
x_20 = l_LeanLink_loadEnv___closed__5;
x_21 = lean_st_ref_set(x_20, x_19, x_17);
x_22 = lean_ctor_get(x_21, 1);
lean_inc(x_22);
lean_dec(x_21);
x_23 = lean_array_size(x_1);
x_24 = 0;
x_25 = l_Array_mapMUnsafe_map___at_LeanLink_loadEnv___spec__2(x_23, x_24, x_1);
x_26 = 0;
x_27 = 0;
x_28 = lean_import_modules(x_25, x_4, x_26, x_27, x_22);
if (lean_obj_tag(x_28) == 0)
{
uint8_t x_29; 
x_29 = !lean_is_exclusive(x_28);
if (x_29 == 0)
{
return x_28;
}
else
{
lean_object* x_30; lean_object* x_31; lean_object* x_32; 
x_30 = lean_ctor_get(x_28, 0);
x_31 = lean_ctor_get(x_28, 1);
lean_inc(x_31);
lean_inc(x_30);
lean_dec(x_28);
x_32 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_32, 0, x_30);
lean_ctor_set(x_32, 1, x_31);
return x_32;
}
}
else
{
uint8_t x_33; 
x_33 = !lean_is_exclusive(x_28);
if (x_33 == 0)
{
return x_28;
}
else
{
lean_object* x_34; lean_object* x_35; lean_object* x_36; 
x_34 = lean_ctor_get(x_28, 0);
x_35 = lean_ctor_get(x_28, 1);
lean_inc(x_35);
lean_inc(x_34);
lean_dec(x_28);
x_36 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_36, 0, x_34);
lean_ctor_set(x_36, 1, x_35);
return x_36;
}
}
}
}
else
{
lean_object* x_52; lean_object* x_53; lean_object* x_54; 
x_52 = lean_ctor_get(x_14, 0);
x_53 = lean_ctor_get(x_14, 1);
lean_inc(x_53);
lean_inc(x_52);
lean_dec(x_14);
if (lean_obj_tag(x_9) == 0)
{
lean_free_object(x_6);
if (lean_obj_tag(x_52) == 0)
{
x_54 = x_4;
goto block_73;
}
else
{
lean_object* x_74; uint8_t x_75; 
x_74 = lean_ctor_get(x_52, 0);
lean_inc(x_74);
lean_dec(x_52);
x_75 = l_LeanLink_loadEnv___closed__2;
if (x_75 == 0)
{
lean_object* x_76; lean_object* x_77; lean_object* x_78; lean_object* x_79; lean_object* x_80; 
x_76 = l_LeanLink_loadEnv___closed__1;
x_77 = lean_unsigned_to_nat(0u);
x_78 = l_String_splitOnAux(x_74, x_76, x_77, x_77, x_77, x_4);
lean_dec(x_74);
x_79 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1(x_78, x_4);
x_80 = l_List_mapTR_loop___at_System_SearchPath_parse___spec__3(x_79, x_4);
x_54 = x_80;
goto block_73;
}
else
{
lean_object* x_81; lean_object* x_82; lean_object* x_83; 
x_81 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_81, 0, x_74);
lean_ctor_set(x_81, 1, x_4);
x_82 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1(x_81, x_4);
x_83 = l_List_mapTR_loop___at_System_SearchPath_parse___spec__3(x_82, x_4);
x_54 = x_83;
goto block_73;
}
}
}
else
{
lean_object* x_84; lean_object* x_85; lean_object* x_86; lean_object* x_87; lean_object* x_88; lean_object* x_89; 
lean_dec(x_52);
x_84 = lean_ctor_get(x_9, 0);
lean_inc(x_84);
lean_dec(x_9);
x_85 = l_LeanLink_loadEnv___closed__6;
lean_inc(x_84);
x_86 = lean_string_append(x_84, x_85);
x_87 = l_LeanLink_loadEnv___closed__7;
x_88 = lean_string_append(x_84, x_87);
x_89 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_89, 0, x_88);
lean_ctor_set(x_89, 1, x_4);
lean_ctor_set_tag(x_6, 1);
lean_ctor_set(x_6, 1, x_89);
lean_ctor_set(x_6, 0, x_86);
x_54 = x_6;
goto block_73;
}
block_73:
{
lean_object* x_55; lean_object* x_56; lean_object* x_57; lean_object* x_58; size_t x_59; size_t x_60; lean_object* x_61; uint32_t x_62; uint8_t x_63; lean_object* x_64; 
x_55 = l_List_appendTR___rarg(x_12, x_54);
x_56 = l_LeanLink_loadEnv___closed__5;
x_57 = lean_st_ref_set(x_56, x_55, x_53);
x_58 = lean_ctor_get(x_57, 1);
lean_inc(x_58);
lean_dec(x_57);
x_59 = lean_array_size(x_1);
x_60 = 0;
x_61 = l_Array_mapMUnsafe_map___at_LeanLink_loadEnv___spec__2(x_59, x_60, x_1);
x_62 = 0;
x_63 = 0;
x_64 = lean_import_modules(x_61, x_4, x_62, x_63, x_58);
if (lean_obj_tag(x_64) == 0)
{
lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; 
x_65 = lean_ctor_get(x_64, 0);
lean_inc(x_65);
x_66 = lean_ctor_get(x_64, 1);
lean_inc(x_66);
if (lean_is_exclusive(x_64)) {
 lean_ctor_release(x_64, 0);
 lean_ctor_release(x_64, 1);
 x_67 = x_64;
} else {
 lean_dec_ref(x_64);
 x_67 = lean_box(0);
}
if (lean_is_scalar(x_67)) {
 x_68 = lean_alloc_ctor(0, 2, 0);
} else {
 x_68 = x_67;
}
lean_ctor_set(x_68, 0, x_65);
lean_ctor_set(x_68, 1, x_66);
return x_68;
}
else
{
lean_object* x_69; lean_object* x_70; lean_object* x_71; lean_object* x_72; 
x_69 = lean_ctor_get(x_64, 0);
lean_inc(x_69);
x_70 = lean_ctor_get(x_64, 1);
lean_inc(x_70);
if (lean_is_exclusive(x_64)) {
 lean_ctor_release(x_64, 0);
 lean_ctor_release(x_64, 1);
 x_71 = x_64;
} else {
 lean_dec_ref(x_64);
 x_71 = lean_box(0);
}
if (lean_is_scalar(x_71)) {
 x_72 = lean_alloc_ctor(1, 2, 0);
} else {
 x_72 = x_71;
}
lean_ctor_set(x_72, 0, x_69);
lean_ctor_set(x_72, 1, x_70);
return x_72;
}
}
}
}
else
{
lean_object* x_90; lean_object* x_91; lean_object* x_92; lean_object* x_93; lean_object* x_94; lean_object* x_95; lean_object* x_96; lean_object* x_97; lean_object* x_98; lean_object* x_99; 
x_90 = lean_ctor_get(x_6, 0);
x_91 = lean_ctor_get(x_6, 1);
lean_inc(x_91);
lean_inc(x_90);
lean_dec(x_6);
x_92 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1(x_7, x_4);
x_93 = l_List_mapTR_loop___at_System_SearchPath_parse___spec__3(x_92, x_4);
x_94 = l_LeanLink_loadEnv___closed__4;
x_95 = lean_io_getenv(x_94, x_91);
x_96 = lean_ctor_get(x_95, 0);
lean_inc(x_96);
x_97 = lean_ctor_get(x_95, 1);
lean_inc(x_97);
if (lean_is_exclusive(x_95)) {
 lean_ctor_release(x_95, 0);
 lean_ctor_release(x_95, 1);
 x_98 = x_95;
} else {
 lean_dec_ref(x_95);
 x_98 = lean_box(0);
}
if (lean_obj_tag(x_90) == 0)
{
if (lean_obj_tag(x_96) == 0)
{
lean_dec(x_98);
x_99 = x_4;
goto block_118;
}
else
{
lean_object* x_119; uint8_t x_120; 
x_119 = lean_ctor_get(x_96, 0);
lean_inc(x_119);
lean_dec(x_96);
x_120 = l_LeanLink_loadEnv___closed__2;
if (x_120 == 0)
{
lean_object* x_121; lean_object* x_122; lean_object* x_123; lean_object* x_124; lean_object* x_125; 
lean_dec(x_98);
x_121 = l_LeanLink_loadEnv___closed__1;
x_122 = lean_unsigned_to_nat(0u);
x_123 = l_String_splitOnAux(x_119, x_121, x_122, x_122, x_122, x_4);
lean_dec(x_119);
x_124 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1(x_123, x_4);
x_125 = l_List_mapTR_loop___at_System_SearchPath_parse___spec__3(x_124, x_4);
x_99 = x_125;
goto block_118;
}
else
{
lean_object* x_126; lean_object* x_127; lean_object* x_128; 
if (lean_is_scalar(x_98)) {
 x_126 = lean_alloc_ctor(1, 2, 0);
} else {
 x_126 = x_98;
 lean_ctor_set_tag(x_126, 1);
}
lean_ctor_set(x_126, 0, x_119);
lean_ctor_set(x_126, 1, x_4);
x_127 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1(x_126, x_4);
x_128 = l_List_mapTR_loop___at_System_SearchPath_parse___spec__3(x_127, x_4);
x_99 = x_128;
goto block_118;
}
}
}
else
{
lean_object* x_129; lean_object* x_130; lean_object* x_131; lean_object* x_132; lean_object* x_133; lean_object* x_134; lean_object* x_135; 
lean_dec(x_96);
x_129 = lean_ctor_get(x_90, 0);
lean_inc(x_129);
lean_dec(x_90);
x_130 = l_LeanLink_loadEnv___closed__6;
lean_inc(x_129);
x_131 = lean_string_append(x_129, x_130);
x_132 = l_LeanLink_loadEnv___closed__7;
x_133 = lean_string_append(x_129, x_132);
if (lean_is_scalar(x_98)) {
 x_134 = lean_alloc_ctor(1, 2, 0);
} else {
 x_134 = x_98;
 lean_ctor_set_tag(x_134, 1);
}
lean_ctor_set(x_134, 0, x_133);
lean_ctor_set(x_134, 1, x_4);
x_135 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_135, 0, x_131);
lean_ctor_set(x_135, 1, x_134);
x_99 = x_135;
goto block_118;
}
block_118:
{
lean_object* x_100; lean_object* x_101; lean_object* x_102; lean_object* x_103; size_t x_104; size_t x_105; lean_object* x_106; uint32_t x_107; uint8_t x_108; lean_object* x_109; 
x_100 = l_List_appendTR___rarg(x_93, x_99);
x_101 = l_LeanLink_loadEnv___closed__5;
x_102 = lean_st_ref_set(x_101, x_100, x_97);
x_103 = lean_ctor_get(x_102, 1);
lean_inc(x_103);
lean_dec(x_102);
x_104 = lean_array_size(x_1);
x_105 = 0;
x_106 = l_Array_mapMUnsafe_map___at_LeanLink_loadEnv___spec__2(x_104, x_105, x_1);
x_107 = 0;
x_108 = 0;
x_109 = lean_import_modules(x_106, x_4, x_107, x_108, x_103);
if (lean_obj_tag(x_109) == 0)
{
lean_object* x_110; lean_object* x_111; lean_object* x_112; lean_object* x_113; 
x_110 = lean_ctor_get(x_109, 0);
lean_inc(x_110);
x_111 = lean_ctor_get(x_109, 1);
lean_inc(x_111);
if (lean_is_exclusive(x_109)) {
 lean_ctor_release(x_109, 0);
 lean_ctor_release(x_109, 1);
 x_112 = x_109;
} else {
 lean_dec_ref(x_109);
 x_112 = lean_box(0);
}
if (lean_is_scalar(x_112)) {
 x_113 = lean_alloc_ctor(0, 2, 0);
} else {
 x_113 = x_112;
}
lean_ctor_set(x_113, 0, x_110);
lean_ctor_set(x_113, 1, x_111);
return x_113;
}
else
{
lean_object* x_114; lean_object* x_115; lean_object* x_116; lean_object* x_117; 
x_114 = lean_ctor_get(x_109, 0);
lean_inc(x_114);
x_115 = lean_ctor_get(x_109, 1);
lean_inc(x_115);
if (lean_is_exclusive(x_109)) {
 lean_ctor_release(x_109, 0);
 lean_ctor_release(x_109, 1);
 x_116 = x_109;
} else {
 lean_dec_ref(x_109);
 x_116 = lean_box(0);
}
if (lean_is_scalar(x_116)) {
 x_117 = lean_alloc_ctor(1, 2, 0);
} else {
 x_117 = x_116;
}
lean_ctor_set(x_117, 0, x_114);
lean_ctor_set(x_117, 1, x_115);
return x_117;
}
}
}
}
}
}
LEAN_EXPORT lean_object* l_Array_mapMUnsafe_map___at_LeanLink_loadEnv___spec__2___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
size_t x_4; size_t x_5; lean_object* x_6; 
x_4 = lean_unbox_usize(x_1);
lean_dec(x_1);
x_5 = lean_unbox_usize(x_2);
lean_dec(x_2);
x_6 = l_Array_mapMUnsafe_map___at_LeanLink_loadEnv___spec__2(x_4, x_5, x_3);
return x_6;
}
}
static lean_object* _init_l_LeanLink_initLeanLink___boxed__const__1() {
_start:
{
uint32_t x_1; lean_object* x_2; 
x_1 = 0;
x_2 = lean_box_uint32(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* leanlink_init(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; 
x_2 = l_LeanLink_initLeanLink___boxed__const__1;
x_3 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_3, 0, x_2);
lean_ctor_set(x_3, 1, x_1);
return x_3;
}
}
LEAN_EXPORT uint8_t l_Std_DHashMap_Internal_AssocList_contains___at_LeanLink_loadEnvExport___spec__1(uint64_t x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_2) == 0)
{
uint8_t x_3; 
x_3 = 0;
return x_3;
}
else
{
lean_object* x_4; lean_object* x_5; uint64_t x_6; uint8_t x_7; 
x_4 = lean_ctor_get(x_2, 0);
lean_inc(x_4);
x_5 = lean_ctor_get(x_2, 2);
lean_inc(x_5);
lean_dec(x_2);
x_6 = lean_unbox_uint64(x_4);
lean_dec(x_4);
x_7 = lean_uint64_dec_eq(x_6, x_1);
if (x_7 == 0)
{
x_2 = x_5;
goto _start;
}
else
{
uint8_t x_9; 
lean_dec(x_5);
x_9 = 1;
return x_9;
}
}
}
}
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_foldlM___at_LeanLink_loadEnvExport___spec__4(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; uint64_t x_9; uint64_t x_10; uint64_t x_11; uint64_t x_12; uint64_t x_13; uint64_t x_14; uint64_t x_15; size_t x_16; size_t x_17; size_t x_18; size_t x_19; size_t x_20; lean_object* x_21; lean_object* x_22; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 2);
x_7 = lean_array_get_size(x_2);
lean_inc(x_1);
lean_inc(x_5);
x_8 = lean_apply_1(x_1, x_5);
x_9 = lean_unbox_uint64(x_8);
lean_dec(x_8);
x_10 = 32;
x_11 = lean_uint64_shift_right(x_9, x_10);
x_12 = lean_uint64_xor(x_9, x_11);
x_13 = 16;
x_14 = lean_uint64_shift_right(x_12, x_13);
x_15 = lean_uint64_xor(x_12, x_14);
x_16 = lean_uint64_to_usize(x_15);
x_17 = lean_usize_of_nat(x_7);
lean_dec(x_7);
x_18 = 1;
x_19 = lean_usize_sub(x_17, x_18);
x_20 = lean_usize_land(x_16, x_19);
x_21 = lean_array_uget(x_2, x_20);
lean_ctor_set(x_3, 2, x_21);
x_22 = lean_array_uset(x_2, x_20, x_3);
x_2 = x_22;
x_3 = x_6;
goto _start;
}
else
{
lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; uint64_t x_29; uint64_t x_30; uint64_t x_31; uint64_t x_32; uint64_t x_33; uint64_t x_34; uint64_t x_35; size_t x_36; size_t x_37; size_t x_38; size_t x_39; size_t x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; 
x_24 = lean_ctor_get(x_3, 0);
x_25 = lean_ctor_get(x_3, 1);
x_26 = lean_ctor_get(x_3, 2);
lean_inc(x_26);
lean_inc(x_25);
lean_inc(x_24);
lean_dec(x_3);
x_27 = lean_array_get_size(x_2);
lean_inc(x_1);
lean_inc(x_24);
x_28 = lean_apply_1(x_1, x_24);
x_29 = lean_unbox_uint64(x_28);
lean_dec(x_28);
x_30 = 32;
x_31 = lean_uint64_shift_right(x_29, x_30);
x_32 = lean_uint64_xor(x_29, x_31);
x_33 = 16;
x_34 = lean_uint64_shift_right(x_32, x_33);
x_35 = lean_uint64_xor(x_32, x_34);
x_36 = lean_uint64_to_usize(x_35);
x_37 = lean_usize_of_nat(x_27);
lean_dec(x_27);
x_38 = 1;
x_39 = lean_usize_sub(x_37, x_38);
x_40 = lean_usize_land(x_36, x_39);
x_41 = lean_array_uget(x_2, x_40);
x_42 = lean_alloc_ctor(1, 3, 0);
lean_ctor_set(x_42, 0, x_24);
lean_ctor_set(x_42, 1, x_25);
lean_ctor_set(x_42, 2, x_41);
x_43 = lean_array_uset(x_2, x_40, x_42);
x_2 = x_43;
x_3 = x_26;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_foldlM___at_LeanLink_loadEnvExport___spec__4___at_LeanLink_loadEnvExport___spec__5(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_2) == 0)
{
return x_1;
}
else
{
uint8_t x_3; 
x_3 = !lean_is_exclusive(x_2);
if (x_3 == 0)
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; uint64_t x_7; uint64_t x_8; uint64_t x_9; uint64_t x_10; uint64_t x_11; uint64_t x_12; uint64_t x_13; uint64_t x_14; size_t x_15; size_t x_16; size_t x_17; size_t x_18; size_t x_19; lean_object* x_20; lean_object* x_21; 
x_4 = lean_ctor_get(x_2, 0);
x_5 = lean_ctor_get(x_2, 2);
x_6 = lean_array_get_size(x_1);
x_7 = 32;
x_8 = lean_unbox_uint64(x_4);
x_9 = lean_uint64_shift_right(x_8, x_7);
x_10 = lean_unbox_uint64(x_4);
x_11 = lean_uint64_xor(x_10, x_9);
x_12 = 16;
x_13 = lean_uint64_shift_right(x_11, x_12);
x_14 = lean_uint64_xor(x_11, x_13);
x_15 = lean_uint64_to_usize(x_14);
x_16 = lean_usize_of_nat(x_6);
lean_dec(x_6);
x_17 = 1;
x_18 = lean_usize_sub(x_16, x_17);
x_19 = lean_usize_land(x_15, x_18);
x_20 = lean_array_uget(x_1, x_19);
lean_ctor_set(x_2, 2, x_20);
x_21 = lean_array_uset(x_1, x_19, x_2);
x_1 = x_21;
x_2 = x_5;
goto _start;
}
else
{
lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; uint64_t x_27; uint64_t x_28; uint64_t x_29; uint64_t x_30; uint64_t x_31; uint64_t x_32; uint64_t x_33; uint64_t x_34; size_t x_35; size_t x_36; size_t x_37; size_t x_38; size_t x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; 
x_23 = lean_ctor_get(x_2, 0);
x_24 = lean_ctor_get(x_2, 1);
x_25 = lean_ctor_get(x_2, 2);
lean_inc(x_25);
lean_inc(x_24);
lean_inc(x_23);
lean_dec(x_2);
x_26 = lean_array_get_size(x_1);
x_27 = 32;
x_28 = lean_unbox_uint64(x_23);
x_29 = lean_uint64_shift_right(x_28, x_27);
x_30 = lean_unbox_uint64(x_23);
x_31 = lean_uint64_xor(x_30, x_29);
x_32 = 16;
x_33 = lean_uint64_shift_right(x_31, x_32);
x_34 = lean_uint64_xor(x_31, x_33);
x_35 = lean_uint64_to_usize(x_34);
x_36 = lean_usize_of_nat(x_26);
lean_dec(x_26);
x_37 = 1;
x_38 = lean_usize_sub(x_36, x_37);
x_39 = lean_usize_land(x_35, x_38);
x_40 = lean_array_uget(x_1, x_39);
x_41 = lean_alloc_ctor(1, 3, 0);
lean_ctor_set(x_41, 0, x_23);
lean_ctor_set(x_41, 1, x_24);
lean_ctor_set(x_41, 2, x_40);
x_42 = lean_array_uset(x_1, x_39, x_41);
x_1 = x_42;
x_2 = x_25;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_Raw_u2080_expand_go___at_LeanLink_loadEnvExport___spec__3(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; uint8_t x_5; 
x_4 = lean_array_get_size(x_2);
x_5 = lean_nat_dec_lt(x_1, x_4);
lean_dec(x_4);
if (x_5 == 0)
{
lean_dec(x_2);
lean_dec(x_1);
return x_3;
}
else
{
lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; 
x_6 = lean_array_fget(x_2, x_1);
x_7 = lean_box(0);
x_8 = lean_array_fset(x_2, x_1, x_7);
x_9 = l_Std_DHashMap_Internal_AssocList_foldlM___at_LeanLink_loadEnvExport___spec__4___at_LeanLink_loadEnvExport___spec__5(x_3, x_6);
x_10 = lean_unsigned_to_nat(1u);
x_11 = lean_nat_add(x_1, x_10);
lean_dec(x_1);
x_1 = x_11;
x_2 = x_8;
x_3 = x_9;
goto _start;
}
}
}
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_Raw_u2080_expand___at_LeanLink_loadEnvExport___spec__2(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; 
x_2 = lean_array_get_size(x_1);
x_3 = lean_unsigned_to_nat(2u);
x_4 = lean_nat_mul(x_2, x_3);
lean_dec(x_2);
x_5 = lean_box(0);
x_6 = lean_mk_array(x_4, x_5);
x_7 = lean_unsigned_to_nat(0u);
x_8 = l_Std_DHashMap_Internal_Raw_u2080_expand_go___at_LeanLink_loadEnvExport___spec__3(x_7, x_1, x_6);
return x_8;
}
}
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_replace___at_LeanLink_loadEnvExport___spec__6(uint64_t x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_object* x_4; 
lean_dec(x_2);
x_4 = lean_box(0);
return x_4;
}
else
{
uint8_t x_5; 
x_5 = !lean_is_exclusive(x_3);
if (x_5 == 0)
{
lean_object* x_6; lean_object* x_7; lean_object* x_8; uint64_t x_9; uint8_t x_10; 
x_6 = lean_ctor_get(x_3, 0);
x_7 = lean_ctor_get(x_3, 1);
x_8 = lean_ctor_get(x_3, 2);
x_9 = lean_unbox_uint64(x_6);
x_10 = lean_uint64_dec_eq(x_9, x_1);
if (x_10 == 0)
{
lean_object* x_11; 
x_11 = l_Std_DHashMap_Internal_AssocList_replace___at_LeanLink_loadEnvExport___spec__6(x_1, x_2, x_8);
lean_ctor_set(x_3, 2, x_11);
return x_3;
}
else
{
lean_object* x_12; 
lean_dec(x_7);
lean_dec(x_6);
x_12 = lean_box_uint64(x_1);
lean_ctor_set(x_3, 1, x_2);
lean_ctor_set(x_3, 0, x_12);
return x_3;
}
}
else
{
lean_object* x_13; lean_object* x_14; lean_object* x_15; uint64_t x_16; uint8_t x_17; 
x_13 = lean_ctor_get(x_3, 0);
x_14 = lean_ctor_get(x_3, 1);
x_15 = lean_ctor_get(x_3, 2);
lean_inc(x_15);
lean_inc(x_14);
lean_inc(x_13);
lean_dec(x_3);
x_16 = lean_unbox_uint64(x_13);
x_17 = lean_uint64_dec_eq(x_16, x_1);
if (x_17 == 0)
{
lean_object* x_18; lean_object* x_19; 
x_18 = l_Std_DHashMap_Internal_AssocList_replace___at_LeanLink_loadEnvExport___spec__6(x_1, x_2, x_15);
x_19 = lean_alloc_ctor(1, 3, 0);
lean_ctor_set(x_19, 0, x_13);
lean_ctor_set(x_19, 1, x_14);
lean_ctor_set(x_19, 2, x_18);
return x_19;
}
else
{
lean_object* x_20; lean_object* x_21; 
lean_dec(x_14);
lean_dec(x_13);
x_20 = lean_box_uint64(x_1);
x_21 = lean_alloc_ctor(1, 3, 0);
lean_ctor_set(x_21, 0, x_20);
lean_ctor_set(x_21, 1, x_2);
lean_ctor_set(x_21, 2, x_15);
return x_21;
}
}
}
}
}
LEAN_EXPORT lean_object* l_Array_foldlMUnsafe_fold___at_LeanLink_loadEnvExport___spec__7(lean_object* x_1, size_t x_2, size_t x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; 
x_5 = lean_usize_dec_eq(x_2, x_3);
if (x_5 == 0)
{
lean_object* x_6; lean_object* x_7; uint8_t x_8; uint8_t x_9; size_t x_10; size_t x_11; 
x_6 = lean_array_uget(x_1, x_2);
x_7 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_8 = lean_string_dec_eq(x_6, x_7);
x_9 = l_instDecidableNot___rarg(x_8);
x_10 = 1;
x_11 = lean_usize_add(x_2, x_10);
if (x_9 == 0)
{
lean_dec(x_6);
x_2 = x_11;
goto _start;
}
else
{
lean_object* x_13; 
x_13 = lean_array_push(x_4, x_6);
x_2 = x_11;
x_4 = x_13;
goto _start;
}
}
else
{
return x_4;
}
}
}
static lean_object* _init_l_LeanLink_loadEnvExport___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = l___private_LeanLink_EnvStore_0__LeanLink_nextHandle;
return x_1;
}
}
static lean_object* _init_l_LeanLink_loadEnvExport___closed__2() {
_start:
{
lean_object* x_1; 
x_1 = l___private_LeanLink_EnvStore_0__LeanLink_envStore;
return x_1;
}
}
static lean_object* _init_l_LeanLink_loadEnvExport___closed__3() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("[LeanLink] loadEnv error: ", 26, 26);
return x_1;
}
}
static lean_object* _init_l_LeanLink_loadEnvExport___closed__4() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked(",", 1, 1);
return x_1;
}
}
static uint8_t _init_l_LeanLink_loadEnvExport___closed__5() {
_start:
{
lean_object* x_1; lean_object* x_2; uint8_t x_3; 
x_1 = l_LeanLink_loadEnvExport___closed__4;
x_2 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_3 = lean_string_dec_eq(x_1, x_2);
return x_3;
}
}
static lean_object* _init_l_LeanLink_loadEnvExport___closed__6() {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_box(0);
x_2 = lean_array_mk(x_1);
return x_2;
}
}
static lean_object* _init_l_LeanLink_loadEnvExport___boxed__const__1() {
_start:
{
uint64_t x_1; lean_object* x_2; 
x_1 = 0;
x_2 = lean_box_uint64(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* leanlink_load_env(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_142; uint8_t x_143; 
x_142 = lean_box(0);
x_143 = l_LeanLink_loadEnvExport___closed__5;
if (x_143 == 0)
{
lean_object* x_144; lean_object* x_145; lean_object* x_146; lean_object* x_147; lean_object* x_148; uint8_t x_149; 
x_144 = l_LeanLink_loadEnvExport___closed__4;
x_145 = lean_unsigned_to_nat(0u);
x_146 = l_String_splitOnAux(x_1, x_144, x_145, x_145, x_145, x_142);
lean_dec(x_1);
x_147 = lean_array_mk(x_146);
x_148 = lean_array_get_size(x_147);
x_149 = lean_nat_dec_lt(x_145, x_148);
if (x_149 == 0)
{
lean_object* x_150; 
lean_dec(x_148);
lean_dec(x_147);
x_150 = l_LeanLink_loadEnvExport___closed__6;
x_4 = x_150;
goto block_141;
}
else
{
uint8_t x_151; 
x_151 = lean_nat_dec_le(x_148, x_148);
if (x_151 == 0)
{
lean_object* x_152; 
lean_dec(x_148);
lean_dec(x_147);
x_152 = l_LeanLink_loadEnvExport___closed__6;
x_4 = x_152;
goto block_141;
}
else
{
size_t x_153; size_t x_154; lean_object* x_155; lean_object* x_156; 
x_153 = 0;
x_154 = lean_usize_of_nat(x_148);
lean_dec(x_148);
x_155 = l_LeanLink_loadEnvExport___closed__6;
x_156 = l_Array_foldlMUnsafe_fold___at_LeanLink_loadEnvExport___spec__7(x_147, x_153, x_154, x_155);
lean_dec(x_147);
x_4 = x_156;
goto block_141;
}
}
}
else
{
lean_object* x_157; lean_object* x_158; lean_object* x_159; lean_object* x_160; uint8_t x_161; 
x_157 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_157, 0, x_1);
lean_ctor_set(x_157, 1, x_142);
x_158 = lean_array_mk(x_157);
x_159 = lean_array_get_size(x_158);
x_160 = lean_unsigned_to_nat(0u);
x_161 = lean_nat_dec_lt(x_160, x_159);
if (x_161 == 0)
{
lean_object* x_162; 
lean_dec(x_159);
lean_dec(x_158);
x_162 = l_LeanLink_loadEnvExport___closed__6;
x_4 = x_162;
goto block_141;
}
else
{
uint8_t x_163; 
x_163 = lean_nat_dec_le(x_159, x_159);
if (x_163 == 0)
{
lean_object* x_164; 
lean_dec(x_159);
lean_dec(x_158);
x_164 = l_LeanLink_loadEnvExport___closed__6;
x_4 = x_164;
goto block_141;
}
else
{
size_t x_165; size_t x_166; lean_object* x_167; lean_object* x_168; 
x_165 = 0;
x_166 = lean_usize_of_nat(x_159);
lean_dec(x_159);
x_167 = l_LeanLink_loadEnvExport___closed__6;
x_168 = l_Array_foldlMUnsafe_fold___at_LeanLink_loadEnvExport___spec__7(x_158, x_165, x_166, x_167);
lean_dec(x_158);
x_4 = x_168;
goto block_141;
}
}
}
block_141:
{
lean_object* x_5; 
x_5 = l_LeanLink_loadEnv(x_4, x_2, x_3);
if (lean_obj_tag(x_5) == 0)
{
lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; uint64_t x_12; uint64_t x_13; uint64_t x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; uint8_t x_22; 
x_6 = lean_ctor_get(x_5, 0);
lean_inc(x_6);
x_7 = lean_ctor_get(x_5, 1);
lean_inc(x_7);
lean_dec(x_5);
x_8 = l_LeanLink_loadEnvExport___closed__1;
x_9 = lean_st_ref_get(x_8, x_7);
x_10 = lean_ctor_get(x_9, 0);
lean_inc(x_10);
x_11 = lean_ctor_get(x_9, 1);
lean_inc(x_11);
lean_dec(x_9);
x_12 = 1;
x_13 = lean_unbox_uint64(x_10);
x_14 = lean_uint64_add(x_13, x_12);
x_15 = lean_box_uint64(x_14);
x_16 = lean_st_ref_set(x_8, x_15, x_11);
x_17 = lean_ctor_get(x_16, 1);
lean_inc(x_17);
lean_dec(x_16);
x_18 = l_LeanLink_loadEnvExport___closed__2;
x_19 = lean_st_ref_take(x_18, x_17);
x_20 = lean_ctor_get(x_19, 0);
lean_inc(x_20);
x_21 = lean_ctor_get(x_19, 1);
lean_inc(x_21);
lean_dec(x_19);
x_22 = !lean_is_exclusive(x_20);
if (x_22 == 0)
{
lean_object* x_23; lean_object* x_24; lean_object* x_25; uint64_t x_26; uint64_t x_27; uint64_t x_28; uint64_t x_29; uint64_t x_30; uint64_t x_31; uint64_t x_32; uint64_t x_33; size_t x_34; size_t x_35; size_t x_36; size_t x_37; size_t x_38; lean_object* x_39; uint64_t x_40; uint8_t x_41; 
x_23 = lean_ctor_get(x_20, 0);
x_24 = lean_ctor_get(x_20, 1);
x_25 = lean_array_get_size(x_24);
x_26 = 32;
x_27 = lean_unbox_uint64(x_10);
x_28 = lean_uint64_shift_right(x_27, x_26);
x_29 = lean_unbox_uint64(x_10);
x_30 = lean_uint64_xor(x_29, x_28);
x_31 = 16;
x_32 = lean_uint64_shift_right(x_30, x_31);
x_33 = lean_uint64_xor(x_30, x_32);
x_34 = lean_uint64_to_usize(x_33);
x_35 = lean_usize_of_nat(x_25);
lean_dec(x_25);
x_36 = 1;
x_37 = lean_usize_sub(x_35, x_36);
x_38 = lean_usize_land(x_34, x_37);
x_39 = lean_array_uget(x_24, x_38);
x_40 = lean_unbox_uint64(x_10);
lean_inc(x_39);
x_41 = l_Std_DHashMap_Internal_AssocList_contains___at_LeanLink_loadEnvExport___spec__1(x_40, x_39);
if (x_41 == 0)
{
lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; uint8_t x_51; 
x_42 = lean_unsigned_to_nat(1u);
x_43 = lean_nat_add(x_23, x_42);
lean_dec(x_23);
lean_inc(x_10);
x_44 = lean_alloc_ctor(1, 3, 0);
lean_ctor_set(x_44, 0, x_10);
lean_ctor_set(x_44, 1, x_6);
lean_ctor_set(x_44, 2, x_39);
x_45 = lean_array_uset(x_24, x_38, x_44);
x_46 = lean_unsigned_to_nat(4u);
x_47 = lean_nat_mul(x_43, x_46);
x_48 = lean_unsigned_to_nat(3u);
x_49 = lean_nat_div(x_47, x_48);
lean_dec(x_47);
x_50 = lean_array_get_size(x_45);
x_51 = lean_nat_dec_le(x_49, x_50);
lean_dec(x_50);
lean_dec(x_49);
if (x_51 == 0)
{
lean_object* x_52; lean_object* x_53; uint8_t x_54; 
x_52 = l_Std_DHashMap_Internal_Raw_u2080_expand___at_LeanLink_loadEnvExport___spec__2(x_45);
lean_ctor_set(x_20, 1, x_52);
lean_ctor_set(x_20, 0, x_43);
x_53 = lean_st_ref_set(x_18, x_20, x_21);
x_54 = !lean_is_exclusive(x_53);
if (x_54 == 0)
{
lean_object* x_55; 
x_55 = lean_ctor_get(x_53, 0);
lean_dec(x_55);
lean_ctor_set(x_53, 0, x_10);
return x_53;
}
else
{
lean_object* x_56; lean_object* x_57; 
x_56 = lean_ctor_get(x_53, 1);
lean_inc(x_56);
lean_dec(x_53);
x_57 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_57, 0, x_10);
lean_ctor_set(x_57, 1, x_56);
return x_57;
}
}
else
{
lean_object* x_58; uint8_t x_59; 
lean_ctor_set(x_20, 1, x_45);
lean_ctor_set(x_20, 0, x_43);
x_58 = lean_st_ref_set(x_18, x_20, x_21);
x_59 = !lean_is_exclusive(x_58);
if (x_59 == 0)
{
lean_object* x_60; 
x_60 = lean_ctor_get(x_58, 0);
lean_dec(x_60);
lean_ctor_set(x_58, 0, x_10);
return x_58;
}
else
{
lean_object* x_61; lean_object* x_62; 
x_61 = lean_ctor_get(x_58, 1);
lean_inc(x_61);
lean_dec(x_58);
x_62 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_62, 0, x_10);
lean_ctor_set(x_62, 1, x_61);
return x_62;
}
}
}
else
{
lean_object* x_63; lean_object* x_64; uint64_t x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; uint8_t x_69; 
x_63 = lean_box(0);
x_64 = lean_array_uset(x_24, x_38, x_63);
x_65 = lean_unbox_uint64(x_10);
x_66 = l_Std_DHashMap_Internal_AssocList_replace___at_LeanLink_loadEnvExport___spec__6(x_65, x_6, x_39);
x_67 = lean_array_uset(x_64, x_38, x_66);
lean_ctor_set(x_20, 1, x_67);
x_68 = lean_st_ref_set(x_18, x_20, x_21);
x_69 = !lean_is_exclusive(x_68);
if (x_69 == 0)
{
lean_object* x_70; 
x_70 = lean_ctor_get(x_68, 0);
lean_dec(x_70);
lean_ctor_set(x_68, 0, x_10);
return x_68;
}
else
{
lean_object* x_71; lean_object* x_72; 
x_71 = lean_ctor_get(x_68, 1);
lean_inc(x_71);
lean_dec(x_68);
x_72 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_72, 0, x_10);
lean_ctor_set(x_72, 1, x_71);
return x_72;
}
}
}
else
{
lean_object* x_73; lean_object* x_74; lean_object* x_75; uint64_t x_76; uint64_t x_77; uint64_t x_78; uint64_t x_79; uint64_t x_80; uint64_t x_81; uint64_t x_82; uint64_t x_83; size_t x_84; size_t x_85; size_t x_86; size_t x_87; size_t x_88; lean_object* x_89; uint64_t x_90; uint8_t x_91; 
x_73 = lean_ctor_get(x_20, 0);
x_74 = lean_ctor_get(x_20, 1);
lean_inc(x_74);
lean_inc(x_73);
lean_dec(x_20);
x_75 = lean_array_get_size(x_74);
x_76 = 32;
x_77 = lean_unbox_uint64(x_10);
x_78 = lean_uint64_shift_right(x_77, x_76);
x_79 = lean_unbox_uint64(x_10);
x_80 = lean_uint64_xor(x_79, x_78);
x_81 = 16;
x_82 = lean_uint64_shift_right(x_80, x_81);
x_83 = lean_uint64_xor(x_80, x_82);
x_84 = lean_uint64_to_usize(x_83);
x_85 = lean_usize_of_nat(x_75);
lean_dec(x_75);
x_86 = 1;
x_87 = lean_usize_sub(x_85, x_86);
x_88 = lean_usize_land(x_84, x_87);
x_89 = lean_array_uget(x_74, x_88);
x_90 = lean_unbox_uint64(x_10);
lean_inc(x_89);
x_91 = l_Std_DHashMap_Internal_AssocList_contains___at_LeanLink_loadEnvExport___spec__1(x_90, x_89);
if (x_91 == 0)
{
lean_object* x_92; lean_object* x_93; lean_object* x_94; lean_object* x_95; lean_object* x_96; lean_object* x_97; lean_object* x_98; lean_object* x_99; lean_object* x_100; uint8_t x_101; 
x_92 = lean_unsigned_to_nat(1u);
x_93 = lean_nat_add(x_73, x_92);
lean_dec(x_73);
lean_inc(x_10);
x_94 = lean_alloc_ctor(1, 3, 0);
lean_ctor_set(x_94, 0, x_10);
lean_ctor_set(x_94, 1, x_6);
lean_ctor_set(x_94, 2, x_89);
x_95 = lean_array_uset(x_74, x_88, x_94);
x_96 = lean_unsigned_to_nat(4u);
x_97 = lean_nat_mul(x_93, x_96);
x_98 = lean_unsigned_to_nat(3u);
x_99 = lean_nat_div(x_97, x_98);
lean_dec(x_97);
x_100 = lean_array_get_size(x_95);
x_101 = lean_nat_dec_le(x_99, x_100);
lean_dec(x_100);
lean_dec(x_99);
if (x_101 == 0)
{
lean_object* x_102; lean_object* x_103; lean_object* x_104; lean_object* x_105; lean_object* x_106; lean_object* x_107; 
x_102 = l_Std_DHashMap_Internal_Raw_u2080_expand___at_LeanLink_loadEnvExport___spec__2(x_95);
x_103 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_103, 0, x_93);
lean_ctor_set(x_103, 1, x_102);
x_104 = lean_st_ref_set(x_18, x_103, x_21);
x_105 = lean_ctor_get(x_104, 1);
lean_inc(x_105);
if (lean_is_exclusive(x_104)) {
 lean_ctor_release(x_104, 0);
 lean_ctor_release(x_104, 1);
 x_106 = x_104;
} else {
 lean_dec_ref(x_104);
 x_106 = lean_box(0);
}
if (lean_is_scalar(x_106)) {
 x_107 = lean_alloc_ctor(0, 2, 0);
} else {
 x_107 = x_106;
}
lean_ctor_set(x_107, 0, x_10);
lean_ctor_set(x_107, 1, x_105);
return x_107;
}
else
{
lean_object* x_108; lean_object* x_109; lean_object* x_110; lean_object* x_111; lean_object* x_112; 
x_108 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_108, 0, x_93);
lean_ctor_set(x_108, 1, x_95);
x_109 = lean_st_ref_set(x_18, x_108, x_21);
x_110 = lean_ctor_get(x_109, 1);
lean_inc(x_110);
if (lean_is_exclusive(x_109)) {
 lean_ctor_release(x_109, 0);
 lean_ctor_release(x_109, 1);
 x_111 = x_109;
} else {
 lean_dec_ref(x_109);
 x_111 = lean_box(0);
}
if (lean_is_scalar(x_111)) {
 x_112 = lean_alloc_ctor(0, 2, 0);
} else {
 x_112 = x_111;
}
lean_ctor_set(x_112, 0, x_10);
lean_ctor_set(x_112, 1, x_110);
return x_112;
}
}
else
{
lean_object* x_113; lean_object* x_114; uint64_t x_115; lean_object* x_116; lean_object* x_117; lean_object* x_118; lean_object* x_119; lean_object* x_120; lean_object* x_121; lean_object* x_122; 
x_113 = lean_box(0);
x_114 = lean_array_uset(x_74, x_88, x_113);
x_115 = lean_unbox_uint64(x_10);
x_116 = l_Std_DHashMap_Internal_AssocList_replace___at_LeanLink_loadEnvExport___spec__6(x_115, x_6, x_89);
x_117 = lean_array_uset(x_114, x_88, x_116);
x_118 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_118, 0, x_73);
lean_ctor_set(x_118, 1, x_117);
x_119 = lean_st_ref_set(x_18, x_118, x_21);
x_120 = lean_ctor_get(x_119, 1);
lean_inc(x_120);
if (lean_is_exclusive(x_119)) {
 lean_ctor_release(x_119, 0);
 lean_ctor_release(x_119, 1);
 x_121 = x_119;
} else {
 lean_dec_ref(x_119);
 x_121 = lean_box(0);
}
if (lean_is_scalar(x_121)) {
 x_122 = lean_alloc_ctor(0, 2, 0);
} else {
 x_122 = x_121;
}
lean_ctor_set(x_122, 0, x_10);
lean_ctor_set(x_122, 1, x_120);
return x_122;
}
}
}
else
{
lean_object* x_123; lean_object* x_124; lean_object* x_125; lean_object* x_126; lean_object* x_127; lean_object* x_128; lean_object* x_129; lean_object* x_130; 
x_123 = lean_ctor_get(x_5, 0);
lean_inc(x_123);
x_124 = lean_ctor_get(x_5, 1);
lean_inc(x_124);
lean_dec(x_5);
x_125 = lean_io_error_to_string(x_123);
x_126 = l_LeanLink_loadEnvExport___closed__3;
x_127 = lean_string_append(x_126, x_125);
lean_dec(x_125);
x_128 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_129 = lean_string_append(x_127, x_128);
x_130 = l_IO_eprintln___at___private_Init_System_IO_0__IO_eprintlnAux___spec__1(x_129, x_124);
if (lean_obj_tag(x_130) == 0)
{
uint8_t x_131; 
x_131 = !lean_is_exclusive(x_130);
if (x_131 == 0)
{
lean_object* x_132; lean_object* x_133; 
x_132 = lean_ctor_get(x_130, 0);
lean_dec(x_132);
x_133 = l_LeanLink_loadEnvExport___boxed__const__1;
lean_ctor_set(x_130, 0, x_133);
return x_130;
}
else
{
lean_object* x_134; lean_object* x_135; lean_object* x_136; 
x_134 = lean_ctor_get(x_130, 1);
lean_inc(x_134);
lean_dec(x_130);
x_135 = l_LeanLink_loadEnvExport___boxed__const__1;
x_136 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_136, 0, x_135);
lean_ctor_set(x_136, 1, x_134);
return x_136;
}
}
else
{
uint8_t x_137; 
x_137 = !lean_is_exclusive(x_130);
if (x_137 == 0)
{
return x_130;
}
else
{
lean_object* x_138; lean_object* x_139; lean_object* x_140; 
x_138 = lean_ctor_get(x_130, 0);
x_139 = lean_ctor_get(x_130, 1);
lean_inc(x_139);
lean_inc(x_138);
lean_dec(x_130);
x_140 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_140, 0, x_138);
lean_ctor_set(x_140, 1, x_139);
return x_140;
}
}
}
}
}
}
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_contains___at_LeanLink_loadEnvExport___spec__1___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint64_t x_3; uint8_t x_4; lean_object* x_5; 
x_3 = lean_unbox_uint64(x_1);
lean_dec(x_1);
x_4 = l_Std_DHashMap_Internal_AssocList_contains___at_LeanLink_loadEnvExport___spec__1(x_3, x_2);
x_5 = lean_box(x_4);
return x_5;
}
}
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_replace___at_LeanLink_loadEnvExport___spec__6___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
uint64_t x_4; lean_object* x_5; 
x_4 = lean_unbox_uint64(x_1);
lean_dec(x_1);
x_5 = l_Std_DHashMap_Internal_AssocList_replace___at_LeanLink_loadEnvExport___spec__6(x_4, x_2, x_3);
return x_5;
}
}
LEAN_EXPORT lean_object* l_Array_foldlMUnsafe_fold___at_LeanLink_loadEnvExport___spec__7___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
size_t x_5; size_t x_6; lean_object* x_7; 
x_5 = lean_unbox_usize(x_2);
lean_dec(x_2);
x_6 = lean_unbox_usize(x_3);
lean_dec(x_3);
x_7 = l_Array_foldlMUnsafe_fold___at_LeanLink_loadEnvExport___spec__7(x_1, x_5, x_6, x_4);
lean_dec(x_1);
return x_7;
}
}
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_erase___at_LeanLink_freeEnvExport___spec__1(uint64_t x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_2) == 0)
{
lean_object* x_3; 
x_3 = lean_box(0);
return x_3;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_2);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; uint64_t x_8; uint8_t x_9; 
x_5 = lean_ctor_get(x_2, 0);
x_6 = lean_ctor_get(x_2, 1);
x_7 = lean_ctor_get(x_2, 2);
x_8 = lean_unbox_uint64(x_5);
x_9 = lean_uint64_dec_eq(x_8, x_1);
if (x_9 == 0)
{
lean_object* x_10; 
x_10 = l_Std_DHashMap_Internal_AssocList_erase___at_LeanLink_freeEnvExport___spec__1(x_1, x_7);
lean_ctor_set(x_2, 2, x_10);
return x_2;
}
else
{
lean_free_object(x_2);
lean_dec(x_6);
lean_dec(x_5);
return x_7;
}
}
else
{
lean_object* x_11; lean_object* x_12; lean_object* x_13; uint64_t x_14; uint8_t x_15; 
x_11 = lean_ctor_get(x_2, 0);
x_12 = lean_ctor_get(x_2, 1);
x_13 = lean_ctor_get(x_2, 2);
lean_inc(x_13);
lean_inc(x_12);
lean_inc(x_11);
lean_dec(x_2);
x_14 = lean_unbox_uint64(x_11);
x_15 = lean_uint64_dec_eq(x_14, x_1);
if (x_15 == 0)
{
lean_object* x_16; lean_object* x_17; 
x_16 = l_Std_DHashMap_Internal_AssocList_erase___at_LeanLink_freeEnvExport___spec__1(x_1, x_13);
x_17 = lean_alloc_ctor(1, 3, 0);
lean_ctor_set(x_17, 0, x_11);
lean_ctor_set(x_17, 1, x_12);
lean_ctor_set(x_17, 2, x_16);
return x_17;
}
else
{
lean_dec(x_12);
lean_dec(x_11);
return x_13;
}
}
}
}
}
LEAN_EXPORT lean_object* leanlink_free_env(uint64_t x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; uint8_t x_7; 
x_3 = l_LeanLink_loadEnvExport___closed__2;
x_4 = lean_st_ref_take(x_3, x_2);
x_5 = lean_ctor_get(x_4, 0);
lean_inc(x_5);
x_6 = lean_ctor_get(x_4, 1);
lean_inc(x_6);
lean_dec(x_4);
x_7 = !lean_is_exclusive(x_5);
if (x_7 == 0)
{
lean_object* x_8; lean_object* x_9; lean_object* x_10; uint64_t x_11; uint64_t x_12; uint64_t x_13; uint64_t x_14; uint64_t x_15; uint64_t x_16; size_t x_17; size_t x_18; size_t x_19; size_t x_20; size_t x_21; lean_object* x_22; uint8_t x_23; 
x_8 = lean_ctor_get(x_5, 0);
x_9 = lean_ctor_get(x_5, 1);
x_10 = lean_array_get_size(x_9);
x_11 = 32;
x_12 = lean_uint64_shift_right(x_1, x_11);
x_13 = lean_uint64_xor(x_1, x_12);
x_14 = 16;
x_15 = lean_uint64_shift_right(x_13, x_14);
x_16 = lean_uint64_xor(x_13, x_15);
x_17 = lean_uint64_to_usize(x_16);
x_18 = lean_usize_of_nat(x_10);
lean_dec(x_10);
x_19 = 1;
x_20 = lean_usize_sub(x_18, x_19);
x_21 = lean_usize_land(x_17, x_20);
x_22 = lean_array_uget(x_9, x_21);
lean_inc(x_22);
x_23 = l_Std_DHashMap_Internal_AssocList_contains___at_LeanLink_loadEnvExport___spec__1(x_1, x_22);
if (x_23 == 0)
{
lean_object* x_24; uint8_t x_25; 
lean_dec(x_22);
x_24 = lean_st_ref_set(x_3, x_5, x_6);
x_25 = !lean_is_exclusive(x_24);
if (x_25 == 0)
{
return x_24;
}
else
{
lean_object* x_26; lean_object* x_27; lean_object* x_28; 
x_26 = lean_ctor_get(x_24, 0);
x_27 = lean_ctor_get(x_24, 1);
lean_inc(x_27);
lean_inc(x_26);
lean_dec(x_24);
x_28 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_28, 0, x_26);
lean_ctor_set(x_28, 1, x_27);
return x_28;
}
}
else
{
lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; uint8_t x_36; 
x_29 = lean_box(0);
x_30 = lean_array_uset(x_9, x_21, x_29);
x_31 = lean_unsigned_to_nat(1u);
x_32 = lean_nat_sub(x_8, x_31);
lean_dec(x_8);
x_33 = l_Std_DHashMap_Internal_AssocList_erase___at_LeanLink_freeEnvExport___spec__1(x_1, x_22);
x_34 = lean_array_uset(x_30, x_21, x_33);
lean_ctor_set(x_5, 1, x_34);
lean_ctor_set(x_5, 0, x_32);
x_35 = lean_st_ref_set(x_3, x_5, x_6);
x_36 = !lean_is_exclusive(x_35);
if (x_36 == 0)
{
return x_35;
}
else
{
lean_object* x_37; lean_object* x_38; lean_object* x_39; 
x_37 = lean_ctor_get(x_35, 0);
x_38 = lean_ctor_get(x_35, 1);
lean_inc(x_38);
lean_inc(x_37);
lean_dec(x_35);
x_39 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_39, 0, x_37);
lean_ctor_set(x_39, 1, x_38);
return x_39;
}
}
}
else
{
lean_object* x_40; lean_object* x_41; lean_object* x_42; uint64_t x_43; uint64_t x_44; uint64_t x_45; uint64_t x_46; uint64_t x_47; uint64_t x_48; size_t x_49; size_t x_50; size_t x_51; size_t x_52; size_t x_53; lean_object* x_54; uint8_t x_55; 
x_40 = lean_ctor_get(x_5, 0);
x_41 = lean_ctor_get(x_5, 1);
lean_inc(x_41);
lean_inc(x_40);
lean_dec(x_5);
x_42 = lean_array_get_size(x_41);
x_43 = 32;
x_44 = lean_uint64_shift_right(x_1, x_43);
x_45 = lean_uint64_xor(x_1, x_44);
x_46 = 16;
x_47 = lean_uint64_shift_right(x_45, x_46);
x_48 = lean_uint64_xor(x_45, x_47);
x_49 = lean_uint64_to_usize(x_48);
x_50 = lean_usize_of_nat(x_42);
lean_dec(x_42);
x_51 = 1;
x_52 = lean_usize_sub(x_50, x_51);
x_53 = lean_usize_land(x_49, x_52);
x_54 = lean_array_uget(x_41, x_53);
lean_inc(x_54);
x_55 = l_Std_DHashMap_Internal_AssocList_contains___at_LeanLink_loadEnvExport___spec__1(x_1, x_54);
if (x_55 == 0)
{
lean_object* x_56; lean_object* x_57; lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; 
lean_dec(x_54);
x_56 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_56, 0, x_40);
lean_ctor_set(x_56, 1, x_41);
x_57 = lean_st_ref_set(x_3, x_56, x_6);
x_58 = lean_ctor_get(x_57, 0);
lean_inc(x_58);
x_59 = lean_ctor_get(x_57, 1);
lean_inc(x_59);
if (lean_is_exclusive(x_57)) {
 lean_ctor_release(x_57, 0);
 lean_ctor_release(x_57, 1);
 x_60 = x_57;
} else {
 lean_dec_ref(x_57);
 x_60 = lean_box(0);
}
if (lean_is_scalar(x_60)) {
 x_61 = lean_alloc_ctor(0, 2, 0);
} else {
 x_61 = x_60;
}
lean_ctor_set(x_61, 0, x_58);
lean_ctor_set(x_61, 1, x_59);
return x_61;
}
else
{
lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; lean_object* x_69; lean_object* x_70; lean_object* x_71; lean_object* x_72; lean_object* x_73; 
x_62 = lean_box(0);
x_63 = lean_array_uset(x_41, x_53, x_62);
x_64 = lean_unsigned_to_nat(1u);
x_65 = lean_nat_sub(x_40, x_64);
lean_dec(x_40);
x_66 = l_Std_DHashMap_Internal_AssocList_erase___at_LeanLink_freeEnvExport___spec__1(x_1, x_54);
x_67 = lean_array_uset(x_63, x_53, x_66);
x_68 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_68, 0, x_65);
lean_ctor_set(x_68, 1, x_67);
x_69 = lean_st_ref_set(x_3, x_68, x_6);
x_70 = lean_ctor_get(x_69, 0);
lean_inc(x_70);
x_71 = lean_ctor_get(x_69, 1);
lean_inc(x_71);
if (lean_is_exclusive(x_69)) {
 lean_ctor_release(x_69, 0);
 lean_ctor_release(x_69, 1);
 x_72 = x_69;
} else {
 lean_dec_ref(x_69);
 x_72 = lean_box(0);
}
if (lean_is_scalar(x_72)) {
 x_73 = lean_alloc_ctor(0, 2, 0);
} else {
 x_73 = x_72;
}
lean_ctor_set(x_73, 0, x_70);
lean_ctor_set(x_73, 1, x_71);
return x_73;
}
}
}
}
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_erase___at_LeanLink_freeEnvExport___spec__1___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint64_t x_3; lean_object* x_4; 
x_3 = lean_unbox_uint64(x_1);
lean_dec(x_1);
x_4 = l_Std_DHashMap_Internal_AssocList_erase___at_LeanLink_freeEnvExport___spec__1(x_3, x_2);
return x_4;
}
}
LEAN_EXPORT lean_object* l_LeanLink_freeEnvExport___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint64_t x_3; lean_object* x_4; 
x_3 = lean_unbox_uint64(x_1);
lean_dec(x_1);
x_4 = leanlink_free_env(x_3, x_2);
return x_4;
}
}
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(uint64_t x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_2) == 0)
{
lean_object* x_3; 
x_3 = lean_box(0);
return x_3;
}
else
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; uint64_t x_7; uint8_t x_8; 
x_4 = lean_ctor_get(x_2, 0);
lean_inc(x_4);
x_5 = lean_ctor_get(x_2, 1);
lean_inc(x_5);
x_6 = lean_ctor_get(x_2, 2);
lean_inc(x_6);
lean_dec(x_2);
x_7 = lean_unbox_uint64(x_4);
lean_dec(x_4);
x_8 = lean_uint64_dec_eq(x_7, x_1);
if (x_8 == 0)
{
lean_dec(x_5);
x_2 = x_6;
goto _start;
}
else
{
lean_object* x_10; 
lean_dec(x_6);
x_10 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_10, 0, x_5);
return x_10;
}
}
}
}
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_foldlM___at_LeanLink_listTheoremsExport___spec__3___rarg(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; 
x_4 = lean_ctor_get(x_3, 0);
lean_inc(x_4);
x_5 = lean_ctor_get(x_3, 1);
lean_inc(x_5);
x_6 = lean_ctor_get(x_3, 2);
lean_inc(x_6);
lean_dec(x_3);
lean_inc(x_1);
x_7 = lean_apply_3(x_1, x_2, x_4, x_5);
x_2 = x_7;
x_3 = x_6;
goto _start;
}
}
}
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_foldlM___at_LeanLink_listTheoremsExport___spec__3(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lean_alloc_closure((void*)(l_Std_DHashMap_Internal_AssocList_foldlM___at_LeanLink_listTheoremsExport___spec__3___rarg), 3, 0);
return x_2;
}
}
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__4___rarg(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = l_Lean_PersistentHashMap_foldlMAux___at_Lean_MetavarContext_getExprAssignmentDomain___spec__2___rarg(x_2, x_1, x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__4(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lean_alloc_closure((void*)(l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__4___rarg___boxed), 3, 0);
return x_2;
}
}
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__5___rarg(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = l_Lean_PersistentHashMap_foldlMAux___at_Lean_MetavarContext_getExprAssignmentDomain___spec__2___rarg(x_2, x_1, x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__5(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lean_alloc_closure((void*)(l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__5___rarg___boxed), 3, 0);
return x_2;
}
}
LEAN_EXPORT lean_object* l_Array_foldlMUnsafe_fold___at_LeanLink_listTheoremsExport___spec__6___rarg(lean_object* x_1, lean_object* x_2, size_t x_3, size_t x_4, lean_object* x_5) {
_start:
{
uint8_t x_6; 
x_6 = lean_usize_dec_eq(x_3, x_4);
if (x_6 == 0)
{
lean_object* x_7; lean_object* x_8; size_t x_9; size_t x_10; 
x_7 = lean_array_uget(x_2, x_3);
lean_inc(x_1);
x_8 = l_Std_DHashMap_Internal_AssocList_foldlM___at_LeanLink_listTheoremsExport___spec__3___rarg(x_1, x_5, x_7);
x_9 = 1;
x_10 = lean_usize_add(x_3, x_9);
x_3 = x_10;
x_5 = x_8;
goto _start;
}
else
{
lean_dec(x_1);
return x_5;
}
}
}
LEAN_EXPORT lean_object* l_Array_foldlMUnsafe_fold___at_LeanLink_listTheoremsExport___spec__6(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lean_alloc_closure((void*)(l_Array_foldlMUnsafe_fold___at_LeanLink_listTheoremsExport___spec__6___rarg___boxed), 5, 0);
return x_2;
}
}
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__7___rarg(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = l_Lean_PersistentHashMap_foldlMAux___at_Lean_MetavarContext_getExprAssignmentDomain___spec__2___rarg(x_2, x_1, x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__7(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lean_alloc_closure((void*)(l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__7___rarg___boxed), 3, 0);
return x_2;
}
}
LEAN_EXPORT lean_object* l_Lean_SMap_fold___at_LeanLink_listTheoremsExport___spec__2___rarg(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; uint8_t x_9; 
x_4 = lean_ctor_get(x_3, 1);
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_5, 1);
x_7 = lean_array_get_size(x_6);
x_8 = lean_unsigned_to_nat(0u);
x_9 = lean_nat_dec_lt(x_8, x_7);
if (x_9 == 0)
{
lean_object* x_10; 
lean_dec(x_7);
x_10 = l_Lean_PersistentHashMap_foldlMAux___at_Lean_MetavarContext_getExprAssignmentDomain___spec__2___rarg(x_1, x_4, x_2);
return x_10;
}
else
{
uint8_t x_11; 
x_11 = lean_nat_dec_le(x_7, x_7);
if (x_11 == 0)
{
lean_object* x_12; 
lean_dec(x_7);
x_12 = l_Lean_PersistentHashMap_foldlMAux___at_Lean_MetavarContext_getExprAssignmentDomain___spec__2___rarg(x_1, x_4, x_2);
return x_12;
}
else
{
size_t x_13; size_t x_14; lean_object* x_15; lean_object* x_16; 
x_13 = 0;
x_14 = lean_usize_of_nat(x_7);
lean_dec(x_7);
lean_inc(x_1);
x_15 = l_Array_foldlMUnsafe_fold___at_LeanLink_listTheoremsExport___spec__6___rarg(x_1, x_6, x_13, x_14, x_2);
x_16 = l_Lean_PersistentHashMap_foldlMAux___at_Lean_MetavarContext_getExprAssignmentDomain___spec__2___rarg(x_1, x_4, x_15);
return x_16;
}
}
}
}
LEAN_EXPORT lean_object* l_Lean_SMap_fold___at_LeanLink_listTheoremsExport___spec__2(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lean_alloc_closure((void*)(l_Lean_SMap_fold___at_LeanLink_listTheoremsExport___spec__2___rarg___boxed), 3, 0);
return x_2;
}
}
LEAN_EXPORT uint8_t l_LeanLink_listTheoremsExport___lambda__1(lean_object* x_1) {
_start:
{
uint8_t x_2; 
x_2 = 0;
return x_2;
}
}
static lean_object* _init_l_LeanLink_listTheoremsExport___lambda__2___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_alloc_closure((void*)(l_LeanLink_listTheoremsExport___lambda__1___boxed), 1, 0);
return x_1;
}
}
LEAN_EXPORT lean_object* l_LeanLink_listTheoremsExport___lambda__2(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; uint8_t x_9; 
x_5 = 1;
x_6 = l_LeanLink_listTheoremsExport___lambda__2___closed__1;
x_7 = l_Lean_Name_toString(x_3, x_5, x_6);
x_8 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_9 = lean_string_dec_eq(x_1, x_8);
if (x_9 == 0)
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; uint8_t x_15; 
x_10 = lean_box(0);
x_11 = lean_unsigned_to_nat(0u);
x_12 = l_String_splitOnAux(x_7, x_1, x_11, x_11, x_11, x_10);
x_13 = l_List_lengthTRAux___rarg(x_12, x_11);
lean_dec(x_12);
x_14 = lean_unsigned_to_nat(1u);
x_15 = lean_nat_dec_lt(x_14, x_13);
lean_dec(x_13);
if (x_15 == 0)
{
lean_dec(x_7);
lean_dec(x_4);
return x_2;
}
else
{
lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; 
x_16 = l_WXF_string(x_7);
lean_dec(x_7);
x_17 = l_WXF_constantToWXF(x_4);
x_18 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_18, 0, x_16);
lean_ctor_set(x_18, 1, x_17);
x_19 = lean_array_push(x_2, x_18);
return x_19;
}
}
else
{
lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; 
x_20 = l_WXF_string(x_7);
lean_dec(x_7);
x_21 = l_WXF_constantToWXF(x_4);
x_22 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_22, 0, x_20);
lean_ctor_set(x_22, 1, x_21);
x_23 = lean_array_push(x_2, x_22);
return x_23;
}
}
}
static lean_object* _init_l_LeanLink_listTheoremsExport___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("ERROR: invalid handle", 21, 21);
return x_1;
}
}
static lean_object* _init_l_LeanLink_listTheoremsExport___closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = l_LeanLink_listTheoremsExport___closed__1;
x_2 = l_WXF_string(x_1);
return x_2;
}
}
static lean_object* _init_l_LeanLink_listTheoremsExport___closed__3() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_WXF_header;
x_2 = l_LeanLink_listTheoremsExport___closed__2;
x_3 = l_ByteArray_append(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* leanlink_list_theorems(uint64_t x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; uint8_t x_6; 
x_4 = l_LeanLink_loadEnvExport___closed__2;
x_5 = lean_st_ref_get(x_4, x_3);
x_6 = !lean_is_exclusive(x_5);
if (x_6 == 0)
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; uint64_t x_10; uint64_t x_11; uint64_t x_12; uint64_t x_13; uint64_t x_14; uint64_t x_15; size_t x_16; size_t x_17; size_t x_18; size_t x_19; size_t x_20; lean_object* x_21; lean_object* x_22; 
x_7 = lean_ctor_get(x_5, 0);
x_8 = lean_ctor_get(x_7, 1);
lean_inc(x_8);
lean_dec(x_7);
x_9 = lean_array_get_size(x_8);
x_10 = 32;
x_11 = lean_uint64_shift_right(x_1, x_10);
x_12 = lean_uint64_xor(x_1, x_11);
x_13 = 16;
x_14 = lean_uint64_shift_right(x_12, x_13);
x_15 = lean_uint64_xor(x_12, x_14);
x_16 = lean_uint64_to_usize(x_15);
x_17 = lean_usize_of_nat(x_9);
lean_dec(x_9);
x_18 = 1;
x_19 = lean_usize_sub(x_17, x_18);
x_20 = lean_usize_land(x_16, x_19);
x_21 = lean_array_uget(x_8, x_20);
lean_dec(x_8);
x_22 = l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(x_1, x_21);
if (lean_obj_tag(x_22) == 0)
{
lean_object* x_23; 
lean_dec(x_2);
x_23 = l_LeanLink_listTheoremsExport___closed__3;
lean_ctor_set(x_5, 0, x_23);
return x_5;
}
else
{
lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; 
x_24 = lean_ctor_get(x_22, 0);
lean_inc(x_24);
lean_dec(x_22);
x_25 = lean_string_utf8_byte_size(x_2);
x_26 = lean_unsigned_to_nat(0u);
x_27 = l_Substring_takeWhileAux___at_Substring_trimLeft___spec__1(x_2, x_25, x_26);
x_28 = l_Substring_takeRightWhileAux___at_Substring_trimRight___spec__1(x_2, x_27, x_25);
x_29 = lean_string_utf8_extract(x_2, x_27, x_28);
lean_dec(x_28);
lean_dec(x_27);
lean_dec(x_2);
x_30 = lean_alloc_closure((void*)(l_LeanLink_listTheoremsExport___lambda__2___boxed), 4, 1);
lean_closure_set(x_30, 0, x_29);
x_31 = lean_ctor_get(x_24, 1);
lean_inc(x_31);
lean_dec(x_24);
x_32 = l_LeanLink_loadEnvExport___closed__6;
x_33 = l_Lean_SMap_fold___at_LeanLink_listTheoremsExport___spec__2___rarg(x_30, x_32, x_31);
lean_dec(x_31);
x_34 = l_WXF_wlAssociation(x_33);
lean_dec(x_33);
x_35 = l_WXF_header;
x_36 = l_ByteArray_append(x_35, x_34);
lean_dec(x_34);
lean_ctor_set(x_5, 0, x_36);
return x_5;
}
}
else
{
lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; uint64_t x_41; uint64_t x_42; uint64_t x_43; uint64_t x_44; uint64_t x_45; uint64_t x_46; size_t x_47; size_t x_48; size_t x_49; size_t x_50; size_t x_51; lean_object* x_52; lean_object* x_53; 
x_37 = lean_ctor_get(x_5, 0);
x_38 = lean_ctor_get(x_5, 1);
lean_inc(x_38);
lean_inc(x_37);
lean_dec(x_5);
x_39 = lean_ctor_get(x_37, 1);
lean_inc(x_39);
lean_dec(x_37);
x_40 = lean_array_get_size(x_39);
x_41 = 32;
x_42 = lean_uint64_shift_right(x_1, x_41);
x_43 = lean_uint64_xor(x_1, x_42);
x_44 = 16;
x_45 = lean_uint64_shift_right(x_43, x_44);
x_46 = lean_uint64_xor(x_43, x_45);
x_47 = lean_uint64_to_usize(x_46);
x_48 = lean_usize_of_nat(x_40);
lean_dec(x_40);
x_49 = 1;
x_50 = lean_usize_sub(x_48, x_49);
x_51 = lean_usize_land(x_47, x_50);
x_52 = lean_array_uget(x_39, x_51);
lean_dec(x_39);
x_53 = l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(x_1, x_52);
if (lean_obj_tag(x_53) == 0)
{
lean_object* x_54; lean_object* x_55; 
lean_dec(x_2);
x_54 = l_LeanLink_listTheoremsExport___closed__3;
x_55 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_55, 0, x_54);
lean_ctor_set(x_55, 1, x_38);
return x_55;
}
else
{
lean_object* x_56; lean_object* x_57; lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; lean_object* x_69; 
x_56 = lean_ctor_get(x_53, 0);
lean_inc(x_56);
lean_dec(x_53);
x_57 = lean_string_utf8_byte_size(x_2);
x_58 = lean_unsigned_to_nat(0u);
x_59 = l_Substring_takeWhileAux___at_Substring_trimLeft___spec__1(x_2, x_57, x_58);
x_60 = l_Substring_takeRightWhileAux___at_Substring_trimRight___spec__1(x_2, x_59, x_57);
x_61 = lean_string_utf8_extract(x_2, x_59, x_60);
lean_dec(x_60);
lean_dec(x_59);
lean_dec(x_2);
x_62 = lean_alloc_closure((void*)(l_LeanLink_listTheoremsExport___lambda__2___boxed), 4, 1);
lean_closure_set(x_62, 0, x_61);
x_63 = lean_ctor_get(x_56, 1);
lean_inc(x_63);
lean_dec(x_56);
x_64 = l_LeanLink_loadEnvExport___closed__6;
x_65 = l_Lean_SMap_fold___at_LeanLink_listTheoremsExport___spec__2___rarg(x_62, x_64, x_63);
lean_dec(x_63);
x_66 = l_WXF_wlAssociation(x_65);
lean_dec(x_65);
x_67 = l_WXF_header;
x_68 = l_ByteArray_append(x_67, x_66);
lean_dec(x_66);
x_69 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_69, 0, x_68);
lean_ctor_set(x_69, 1, x_38);
return x_69;
}
}
}
}
LEAN_EXPORT lean_object* l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint64_t x_3; lean_object* x_4; 
x_3 = lean_unbox_uint64(x_1);
lean_dec(x_1);
x_4 = l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(x_3, x_2);
return x_4;
}
}
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__4___rarg___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__4___rarg(x_1, x_2, x_3);
lean_dec(x_1);
return x_4;
}
}
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__5___rarg___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__5___rarg(x_1, x_2, x_3);
lean_dec(x_1);
return x_4;
}
}
LEAN_EXPORT lean_object* l_Array_foldlMUnsafe_fold___at_LeanLink_listTheoremsExport___spec__6___rarg___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
size_t x_6; size_t x_7; lean_object* x_8; 
x_6 = lean_unbox_usize(x_3);
lean_dec(x_3);
x_7 = lean_unbox_usize(x_4);
lean_dec(x_4);
x_8 = l_Array_foldlMUnsafe_fold___at_LeanLink_listTheoremsExport___spec__6___rarg(x_1, x_2, x_6, x_7, x_5);
lean_dec(x_2);
return x_8;
}
}
LEAN_EXPORT lean_object* l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__7___rarg___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = l_Lean_PersistentHashMap_foldlM___at_LeanLink_listTheoremsExport___spec__7___rarg(x_1, x_2, x_3);
lean_dec(x_1);
return x_4;
}
}
LEAN_EXPORT lean_object* l_Lean_SMap_fold___at_LeanLink_listTheoremsExport___spec__2___rarg___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = l_Lean_SMap_fold___at_LeanLink_listTheoremsExport___spec__2___rarg(x_1, x_2, x_3);
lean_dec(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* l_LeanLink_listTheoremsExport___lambda__1___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = l_LeanLink_listTheoremsExport___lambda__1(x_1);
lean_dec(x_1);
x_3 = lean_box(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* l_LeanLink_listTheoremsExport___lambda__2___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = l_LeanLink_listTheoremsExport___lambda__2(x_1, x_2, x_3, x_4);
lean_dec(x_1);
return x_5;
}
}
LEAN_EXPORT lean_object* l_LeanLink_listTheoremsExport___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
uint64_t x_4; lean_object* x_5; 
x_4 = lean_unbox_uint64(x_1);
lean_dec(x_1);
x_5 = leanlink_list_theorems(x_4, x_2, x_3);
return x_5;
}
}
LEAN_EXPORT lean_object* l_LeanLink_listConstantNamesExport___lambda__1(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; uint8_t x_9; 
x_5 = 1;
x_6 = l_LeanLink_listTheoremsExport___lambda__2___closed__1;
x_7 = l_Lean_Name_toString(x_3, x_5, x_6);
x_8 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_9 = lean_string_dec_eq(x_1, x_8);
if (x_9 == 0)
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; uint8_t x_15; 
x_10 = lean_box(0);
x_11 = lean_unsigned_to_nat(0u);
x_12 = l_String_splitOnAux(x_7, x_1, x_11, x_11, x_11, x_10);
x_13 = l_List_lengthTRAux___rarg(x_12, x_11);
lean_dec(x_12);
x_14 = lean_unsigned_to_nat(1u);
x_15 = lean_nat_dec_lt(x_14, x_13);
lean_dec(x_13);
if (x_15 == 0)
{
lean_dec(x_7);
return x_2;
}
else
{
lean_object* x_16; lean_object* x_17; 
x_16 = l_WXF_string(x_7);
lean_dec(x_7);
x_17 = lean_array_push(x_2, x_16);
return x_17;
}
}
else
{
lean_object* x_18; lean_object* x_19; 
x_18 = l_WXF_string(x_7);
lean_dec(x_7);
x_19 = lean_array_push(x_2, x_18);
return x_19;
}
}
}
LEAN_EXPORT lean_object* leanlink_list_constant_names(uint64_t x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; uint8_t x_6; 
x_4 = l_LeanLink_loadEnvExport___closed__2;
x_5 = lean_st_ref_get(x_4, x_3);
x_6 = !lean_is_exclusive(x_5);
if (x_6 == 0)
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; uint64_t x_10; uint64_t x_11; uint64_t x_12; uint64_t x_13; uint64_t x_14; uint64_t x_15; size_t x_16; size_t x_17; size_t x_18; size_t x_19; size_t x_20; lean_object* x_21; lean_object* x_22; 
x_7 = lean_ctor_get(x_5, 0);
x_8 = lean_ctor_get(x_7, 1);
lean_inc(x_8);
lean_dec(x_7);
x_9 = lean_array_get_size(x_8);
x_10 = 32;
x_11 = lean_uint64_shift_right(x_1, x_10);
x_12 = lean_uint64_xor(x_1, x_11);
x_13 = 16;
x_14 = lean_uint64_shift_right(x_12, x_13);
x_15 = lean_uint64_xor(x_12, x_14);
x_16 = lean_uint64_to_usize(x_15);
x_17 = lean_usize_of_nat(x_9);
lean_dec(x_9);
x_18 = 1;
x_19 = lean_usize_sub(x_17, x_18);
x_20 = lean_usize_land(x_16, x_19);
x_21 = lean_array_uget(x_8, x_20);
lean_dec(x_8);
x_22 = l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(x_1, x_21);
if (lean_obj_tag(x_22) == 0)
{
lean_object* x_23; 
lean_dec(x_2);
x_23 = l_LeanLink_listTheoremsExport___closed__3;
lean_ctor_set(x_5, 0, x_23);
return x_5;
}
else
{
lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; 
x_24 = lean_ctor_get(x_22, 0);
lean_inc(x_24);
lean_dec(x_22);
x_25 = lean_string_utf8_byte_size(x_2);
x_26 = lean_unsigned_to_nat(0u);
x_27 = l_Substring_takeWhileAux___at_Substring_trimLeft___spec__1(x_2, x_25, x_26);
x_28 = l_Substring_takeRightWhileAux___at_Substring_trimRight___spec__1(x_2, x_27, x_25);
x_29 = lean_string_utf8_extract(x_2, x_27, x_28);
lean_dec(x_28);
lean_dec(x_27);
lean_dec(x_2);
x_30 = lean_alloc_closure((void*)(l_LeanLink_listConstantNamesExport___lambda__1___boxed), 4, 1);
lean_closure_set(x_30, 0, x_29);
x_31 = lean_ctor_get(x_24, 1);
lean_inc(x_31);
lean_dec(x_24);
x_32 = l_LeanLink_loadEnvExport___closed__6;
x_33 = l_Lean_SMap_fold___at_LeanLink_listTheoremsExport___spec__2___rarg(x_30, x_32, x_31);
lean_dec(x_31);
x_34 = l_WXF_wlList(x_33);
lean_dec(x_33);
x_35 = l_WXF_header;
x_36 = l_ByteArray_append(x_35, x_34);
lean_dec(x_34);
lean_ctor_set(x_5, 0, x_36);
return x_5;
}
}
else
{
lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; uint64_t x_41; uint64_t x_42; uint64_t x_43; uint64_t x_44; uint64_t x_45; uint64_t x_46; size_t x_47; size_t x_48; size_t x_49; size_t x_50; size_t x_51; lean_object* x_52; lean_object* x_53; 
x_37 = lean_ctor_get(x_5, 0);
x_38 = lean_ctor_get(x_5, 1);
lean_inc(x_38);
lean_inc(x_37);
lean_dec(x_5);
x_39 = lean_ctor_get(x_37, 1);
lean_inc(x_39);
lean_dec(x_37);
x_40 = lean_array_get_size(x_39);
x_41 = 32;
x_42 = lean_uint64_shift_right(x_1, x_41);
x_43 = lean_uint64_xor(x_1, x_42);
x_44 = 16;
x_45 = lean_uint64_shift_right(x_43, x_44);
x_46 = lean_uint64_xor(x_43, x_45);
x_47 = lean_uint64_to_usize(x_46);
x_48 = lean_usize_of_nat(x_40);
lean_dec(x_40);
x_49 = 1;
x_50 = lean_usize_sub(x_48, x_49);
x_51 = lean_usize_land(x_47, x_50);
x_52 = lean_array_uget(x_39, x_51);
lean_dec(x_39);
x_53 = l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(x_1, x_52);
if (lean_obj_tag(x_53) == 0)
{
lean_object* x_54; lean_object* x_55; 
lean_dec(x_2);
x_54 = l_LeanLink_listTheoremsExport___closed__3;
x_55 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_55, 0, x_54);
lean_ctor_set(x_55, 1, x_38);
return x_55;
}
else
{
lean_object* x_56; lean_object* x_57; lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; lean_object* x_69; 
x_56 = lean_ctor_get(x_53, 0);
lean_inc(x_56);
lean_dec(x_53);
x_57 = lean_string_utf8_byte_size(x_2);
x_58 = lean_unsigned_to_nat(0u);
x_59 = l_Substring_takeWhileAux___at_Substring_trimLeft___spec__1(x_2, x_57, x_58);
x_60 = l_Substring_takeRightWhileAux___at_Substring_trimRight___spec__1(x_2, x_59, x_57);
x_61 = lean_string_utf8_extract(x_2, x_59, x_60);
lean_dec(x_60);
lean_dec(x_59);
lean_dec(x_2);
x_62 = lean_alloc_closure((void*)(l_LeanLink_listConstantNamesExport___lambda__1___boxed), 4, 1);
lean_closure_set(x_62, 0, x_61);
x_63 = lean_ctor_get(x_56, 1);
lean_inc(x_63);
lean_dec(x_56);
x_64 = l_LeanLink_loadEnvExport___closed__6;
x_65 = l_Lean_SMap_fold___at_LeanLink_listTheoremsExport___spec__2___rarg(x_62, x_64, x_63);
lean_dec(x_63);
x_66 = l_WXF_wlList(x_65);
lean_dec(x_65);
x_67 = l_WXF_header;
x_68 = l_ByteArray_append(x_67, x_66);
lean_dec(x_66);
x_69 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_69, 0, x_68);
lean_ctor_set(x_69, 1, x_38);
return x_69;
}
}
}
}
LEAN_EXPORT lean_object* l_LeanLink_listConstantNamesExport___lambda__1___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = l_LeanLink_listConstantNamesExport___lambda__1(x_1, x_2, x_3, x_4);
lean_dec(x_4);
lean_dec(x_1);
return x_5;
}
}
LEAN_EXPORT lean_object* l_LeanLink_listConstantNamesExport___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
uint64_t x_4; lean_object* x_5; 
x_4 = lean_unbox_uint64(x_1);
lean_dec(x_1);
x_5 = leanlink_list_constant_names(x_4, x_2, x_3);
return x_5;
}
}
LEAN_EXPORT lean_object* l_LeanLink_listConstantKindsExport___lambda__1(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; uint8_t x_9; 
x_5 = 1;
x_6 = l_LeanLink_listTheoremsExport___lambda__2___closed__1;
x_7 = l_Lean_Name_toString(x_3, x_5, x_6);
x_8 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_9 = lean_string_dec_eq(x_1, x_8);
if (x_9 == 0)
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; uint8_t x_15; 
x_10 = lean_box(0);
x_11 = lean_unsigned_to_nat(0u);
x_12 = l_String_splitOnAux(x_7, x_1, x_11, x_11, x_11, x_10);
x_13 = l_List_lengthTRAux___rarg(x_12, x_11);
lean_dec(x_12);
x_14 = lean_unsigned_to_nat(1u);
x_15 = lean_nat_dec_lt(x_14, x_13);
lean_dec(x_13);
if (x_15 == 0)
{
lean_dec(x_7);
return x_2;
}
else
{
lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; 
x_16 = l_WXF_string(x_7);
lean_dec(x_7);
x_17 = l_WXF_constantKind(x_4);
x_18 = l_WXF_string(x_17);
lean_dec(x_17);
x_19 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_19, 0, x_16);
lean_ctor_set(x_19, 1, x_18);
x_20 = lean_array_push(x_2, x_19);
return x_20;
}
}
else
{
lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; 
x_21 = l_WXF_string(x_7);
lean_dec(x_7);
x_22 = l_WXF_constantKind(x_4);
x_23 = l_WXF_string(x_22);
lean_dec(x_22);
x_24 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_24, 0, x_21);
lean_ctor_set(x_24, 1, x_23);
x_25 = lean_array_push(x_2, x_24);
return x_25;
}
}
}
LEAN_EXPORT lean_object* leanlink_list_constant_kinds(uint64_t x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; uint8_t x_6; 
x_4 = l_LeanLink_loadEnvExport___closed__2;
x_5 = lean_st_ref_get(x_4, x_3);
x_6 = !lean_is_exclusive(x_5);
if (x_6 == 0)
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; uint64_t x_10; uint64_t x_11; uint64_t x_12; uint64_t x_13; uint64_t x_14; uint64_t x_15; size_t x_16; size_t x_17; size_t x_18; size_t x_19; size_t x_20; lean_object* x_21; lean_object* x_22; 
x_7 = lean_ctor_get(x_5, 0);
x_8 = lean_ctor_get(x_7, 1);
lean_inc(x_8);
lean_dec(x_7);
x_9 = lean_array_get_size(x_8);
x_10 = 32;
x_11 = lean_uint64_shift_right(x_1, x_10);
x_12 = lean_uint64_xor(x_1, x_11);
x_13 = 16;
x_14 = lean_uint64_shift_right(x_12, x_13);
x_15 = lean_uint64_xor(x_12, x_14);
x_16 = lean_uint64_to_usize(x_15);
x_17 = lean_usize_of_nat(x_9);
lean_dec(x_9);
x_18 = 1;
x_19 = lean_usize_sub(x_17, x_18);
x_20 = lean_usize_land(x_16, x_19);
x_21 = lean_array_uget(x_8, x_20);
lean_dec(x_8);
x_22 = l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(x_1, x_21);
if (lean_obj_tag(x_22) == 0)
{
lean_object* x_23; 
lean_dec(x_2);
x_23 = l_LeanLink_listTheoremsExport___closed__3;
lean_ctor_set(x_5, 0, x_23);
return x_5;
}
else
{
lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; 
x_24 = lean_ctor_get(x_22, 0);
lean_inc(x_24);
lean_dec(x_22);
x_25 = lean_string_utf8_byte_size(x_2);
x_26 = lean_unsigned_to_nat(0u);
x_27 = l_Substring_takeWhileAux___at_Substring_trimLeft___spec__1(x_2, x_25, x_26);
x_28 = l_Substring_takeRightWhileAux___at_Substring_trimRight___spec__1(x_2, x_27, x_25);
x_29 = lean_string_utf8_extract(x_2, x_27, x_28);
lean_dec(x_28);
lean_dec(x_27);
lean_dec(x_2);
x_30 = lean_alloc_closure((void*)(l_LeanLink_listConstantKindsExport___lambda__1___boxed), 4, 1);
lean_closure_set(x_30, 0, x_29);
x_31 = lean_ctor_get(x_24, 1);
lean_inc(x_31);
lean_dec(x_24);
x_32 = l_LeanLink_loadEnvExport___closed__6;
x_33 = l_Lean_SMap_fold___at_LeanLink_listTheoremsExport___spec__2___rarg(x_30, x_32, x_31);
lean_dec(x_31);
x_34 = l_WXF_wlAssociation(x_33);
lean_dec(x_33);
x_35 = l_WXF_header;
x_36 = l_ByteArray_append(x_35, x_34);
lean_dec(x_34);
lean_ctor_set(x_5, 0, x_36);
return x_5;
}
}
else
{
lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; uint64_t x_41; uint64_t x_42; uint64_t x_43; uint64_t x_44; uint64_t x_45; uint64_t x_46; size_t x_47; size_t x_48; size_t x_49; size_t x_50; size_t x_51; lean_object* x_52; lean_object* x_53; 
x_37 = lean_ctor_get(x_5, 0);
x_38 = lean_ctor_get(x_5, 1);
lean_inc(x_38);
lean_inc(x_37);
lean_dec(x_5);
x_39 = lean_ctor_get(x_37, 1);
lean_inc(x_39);
lean_dec(x_37);
x_40 = lean_array_get_size(x_39);
x_41 = 32;
x_42 = lean_uint64_shift_right(x_1, x_41);
x_43 = lean_uint64_xor(x_1, x_42);
x_44 = 16;
x_45 = lean_uint64_shift_right(x_43, x_44);
x_46 = lean_uint64_xor(x_43, x_45);
x_47 = lean_uint64_to_usize(x_46);
x_48 = lean_usize_of_nat(x_40);
lean_dec(x_40);
x_49 = 1;
x_50 = lean_usize_sub(x_48, x_49);
x_51 = lean_usize_land(x_47, x_50);
x_52 = lean_array_uget(x_39, x_51);
lean_dec(x_39);
x_53 = l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(x_1, x_52);
if (lean_obj_tag(x_53) == 0)
{
lean_object* x_54; lean_object* x_55; 
lean_dec(x_2);
x_54 = l_LeanLink_listTheoremsExport___closed__3;
x_55 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_55, 0, x_54);
lean_ctor_set(x_55, 1, x_38);
return x_55;
}
else
{
lean_object* x_56; lean_object* x_57; lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; lean_object* x_69; 
x_56 = lean_ctor_get(x_53, 0);
lean_inc(x_56);
lean_dec(x_53);
x_57 = lean_string_utf8_byte_size(x_2);
x_58 = lean_unsigned_to_nat(0u);
x_59 = l_Substring_takeWhileAux___at_Substring_trimLeft___spec__1(x_2, x_57, x_58);
x_60 = l_Substring_takeRightWhileAux___at_Substring_trimRight___spec__1(x_2, x_59, x_57);
x_61 = lean_string_utf8_extract(x_2, x_59, x_60);
lean_dec(x_60);
lean_dec(x_59);
lean_dec(x_2);
x_62 = lean_alloc_closure((void*)(l_LeanLink_listConstantKindsExport___lambda__1___boxed), 4, 1);
lean_closure_set(x_62, 0, x_61);
x_63 = lean_ctor_get(x_56, 1);
lean_inc(x_63);
lean_dec(x_56);
x_64 = l_LeanLink_loadEnvExport___closed__6;
x_65 = l_Lean_SMap_fold___at_LeanLink_listTheoremsExport___spec__2___rarg(x_62, x_64, x_63);
lean_dec(x_63);
x_66 = l_WXF_wlAssociation(x_65);
lean_dec(x_65);
x_67 = l_WXF_header;
x_68 = l_ByteArray_append(x_67, x_66);
lean_dec(x_66);
x_69 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_69, 0, x_68);
lean_ctor_set(x_69, 1, x_38);
return x_69;
}
}
}
}
LEAN_EXPORT lean_object* l_LeanLink_listConstantKindsExport___lambda__1___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = l_LeanLink_listConstantKindsExport___lambda__1(x_1, x_2, x_3, x_4);
lean_dec(x_4);
lean_dec(x_1);
return x_5;
}
}
LEAN_EXPORT lean_object* l_LeanLink_listConstantKindsExport___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
uint64_t x_4; lean_object* x_5; 
x_4 = lean_unbox_uint64(x_1);
lean_dec(x_1);
x_5 = leanlink_list_constant_kinds(x_4, x_2, x_3);
return x_5;
}
}
static lean_object* _init_l_LeanLink_getTypeExport___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("ERROR: constant not found: ", 27, 27);
return x_1;
}
}
LEAN_EXPORT lean_object* leanlink_get_type(uint64_t x_1, lean_object* x_2, uint32_t x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; lean_object* x_6; uint8_t x_7; 
x_5 = l_LeanLink_loadEnvExport___closed__2;
x_6 = lean_st_ref_get(x_5, x_4);
x_7 = !lean_is_exclusive(x_6);
if (x_7 == 0)
{
lean_object* x_8; lean_object* x_9; lean_object* x_10; uint64_t x_11; uint64_t x_12; uint64_t x_13; uint64_t x_14; uint64_t x_15; uint64_t x_16; size_t x_17; size_t x_18; size_t x_19; size_t x_20; size_t x_21; lean_object* x_22; lean_object* x_23; 
x_8 = lean_ctor_get(x_6, 0);
x_9 = lean_ctor_get(x_8, 1);
lean_inc(x_9);
lean_dec(x_8);
x_10 = lean_array_get_size(x_9);
x_11 = 32;
x_12 = lean_uint64_shift_right(x_1, x_11);
x_13 = lean_uint64_xor(x_1, x_12);
x_14 = 16;
x_15 = lean_uint64_shift_right(x_13, x_14);
x_16 = lean_uint64_xor(x_13, x_15);
x_17 = lean_uint64_to_usize(x_16);
x_18 = lean_usize_of_nat(x_10);
lean_dec(x_10);
x_19 = 1;
x_20 = lean_usize_sub(x_18, x_19);
x_21 = lean_usize_land(x_17, x_20);
x_22 = lean_array_uget(x_9, x_21);
lean_dec(x_9);
x_23 = l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(x_1, x_22);
if (lean_obj_tag(x_23) == 0)
{
lean_object* x_24; 
lean_dec(x_2);
x_24 = l_LeanLink_listTheoremsExport___closed__3;
lean_ctor_set(x_6, 0, x_24);
return x_6;
}
else
{
lean_object* x_25; lean_object* x_26; lean_object* x_27; 
x_25 = lean_ctor_get(x_23, 0);
lean_inc(x_25);
lean_dec(x_23);
lean_inc(x_2);
x_26 = l_String_toName(x_2);
x_27 = lean_environment_find(x_25, x_26);
if (lean_obj_tag(x_27) == 0)
{
lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; 
x_28 = l_LeanLink_getTypeExport___closed__1;
x_29 = lean_string_append(x_28, x_2);
lean_dec(x_2);
x_30 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_31 = lean_string_append(x_29, x_30);
x_32 = l_WXF_string(x_31);
lean_dec(x_31);
x_33 = l_WXF_header;
x_34 = l_ByteArray_append(x_33, x_32);
lean_dec(x_32);
lean_ctor_set(x_6, 0, x_34);
return x_6;
}
else
{
lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; 
lean_dec(x_2);
x_35 = lean_ctor_get(x_27, 0);
lean_inc(x_35);
lean_dec(x_27);
x_36 = l_Lean_ConstantInfo_type(x_35);
lean_dec(x_35);
x_37 = lean_uint32_to_nat(x_3);
x_38 = l_WXF_exprToWXF(x_36, x_37);
x_39 = l_WXF_header;
x_40 = l_ByteArray_append(x_39, x_38);
lean_dec(x_38);
lean_ctor_set(x_6, 0, x_40);
return x_6;
}
}
}
else
{
lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; uint64_t x_45; uint64_t x_46; uint64_t x_47; uint64_t x_48; uint64_t x_49; uint64_t x_50; size_t x_51; size_t x_52; size_t x_53; size_t x_54; size_t x_55; lean_object* x_56; lean_object* x_57; 
x_41 = lean_ctor_get(x_6, 0);
x_42 = lean_ctor_get(x_6, 1);
lean_inc(x_42);
lean_inc(x_41);
lean_dec(x_6);
x_43 = lean_ctor_get(x_41, 1);
lean_inc(x_43);
lean_dec(x_41);
x_44 = lean_array_get_size(x_43);
x_45 = 32;
x_46 = lean_uint64_shift_right(x_1, x_45);
x_47 = lean_uint64_xor(x_1, x_46);
x_48 = 16;
x_49 = lean_uint64_shift_right(x_47, x_48);
x_50 = lean_uint64_xor(x_47, x_49);
x_51 = lean_uint64_to_usize(x_50);
x_52 = lean_usize_of_nat(x_44);
lean_dec(x_44);
x_53 = 1;
x_54 = lean_usize_sub(x_52, x_53);
x_55 = lean_usize_land(x_51, x_54);
x_56 = lean_array_uget(x_43, x_55);
lean_dec(x_43);
x_57 = l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(x_1, x_56);
if (lean_obj_tag(x_57) == 0)
{
lean_object* x_58; lean_object* x_59; 
lean_dec(x_2);
x_58 = l_LeanLink_listTheoremsExport___closed__3;
x_59 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_59, 0, x_58);
lean_ctor_set(x_59, 1, x_42);
return x_59;
}
else
{
lean_object* x_60; lean_object* x_61; lean_object* x_62; 
x_60 = lean_ctor_get(x_57, 0);
lean_inc(x_60);
lean_dec(x_57);
lean_inc(x_2);
x_61 = l_String_toName(x_2);
x_62 = lean_environment_find(x_60, x_61);
if (lean_obj_tag(x_62) == 0)
{
lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; lean_object* x_69; lean_object* x_70; 
x_63 = l_LeanLink_getTypeExport___closed__1;
x_64 = lean_string_append(x_63, x_2);
lean_dec(x_2);
x_65 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_66 = lean_string_append(x_64, x_65);
x_67 = l_WXF_string(x_66);
lean_dec(x_66);
x_68 = l_WXF_header;
x_69 = l_ByteArray_append(x_68, x_67);
lean_dec(x_67);
x_70 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_70, 0, x_69);
lean_ctor_set(x_70, 1, x_42);
return x_70;
}
else
{
lean_object* x_71; lean_object* x_72; lean_object* x_73; lean_object* x_74; lean_object* x_75; lean_object* x_76; lean_object* x_77; 
lean_dec(x_2);
x_71 = lean_ctor_get(x_62, 0);
lean_inc(x_71);
lean_dec(x_62);
x_72 = l_Lean_ConstantInfo_type(x_71);
lean_dec(x_71);
x_73 = lean_uint32_to_nat(x_3);
x_74 = l_WXF_exprToWXF(x_72, x_73);
x_75 = l_WXF_header;
x_76 = l_ByteArray_append(x_75, x_74);
lean_dec(x_74);
x_77 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_77, 0, x_76);
lean_ctor_set(x_77, 1, x_42);
return x_77;
}
}
}
}
}
LEAN_EXPORT lean_object* l_LeanLink_getTypeExport___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint64_t x_5; uint32_t x_6; lean_object* x_7; 
x_5 = lean_unbox_uint64(x_1);
lean_dec(x_1);
x_6 = lean_unbox_uint32(x_3);
lean_dec(x_3);
x_7 = leanlink_get_type(x_5, x_2, x_6, x_4);
return x_7;
}
}
static lean_object* _init_l_LeanLink_getValueExport___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("No value for: ", 14, 14);
return x_1;
}
}
LEAN_EXPORT lean_object* leanlink_get_value(uint64_t x_1, lean_object* x_2, uint32_t x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; lean_object* x_6; uint8_t x_7; 
x_5 = l_LeanLink_loadEnvExport___closed__2;
x_6 = lean_st_ref_get(x_5, x_4);
x_7 = !lean_is_exclusive(x_6);
if (x_7 == 0)
{
lean_object* x_8; lean_object* x_9; lean_object* x_10; uint64_t x_11; uint64_t x_12; uint64_t x_13; uint64_t x_14; uint64_t x_15; uint64_t x_16; size_t x_17; size_t x_18; size_t x_19; size_t x_20; size_t x_21; lean_object* x_22; lean_object* x_23; 
x_8 = lean_ctor_get(x_6, 0);
x_9 = lean_ctor_get(x_8, 1);
lean_inc(x_9);
lean_dec(x_8);
x_10 = lean_array_get_size(x_9);
x_11 = 32;
x_12 = lean_uint64_shift_right(x_1, x_11);
x_13 = lean_uint64_xor(x_1, x_12);
x_14 = 16;
x_15 = lean_uint64_shift_right(x_13, x_14);
x_16 = lean_uint64_xor(x_13, x_15);
x_17 = lean_uint64_to_usize(x_16);
x_18 = lean_usize_of_nat(x_10);
lean_dec(x_10);
x_19 = 1;
x_20 = lean_usize_sub(x_18, x_19);
x_21 = lean_usize_land(x_17, x_20);
x_22 = lean_array_uget(x_9, x_21);
lean_dec(x_9);
x_23 = l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(x_1, x_22);
if (lean_obj_tag(x_23) == 0)
{
lean_object* x_24; 
lean_dec(x_2);
x_24 = l_LeanLink_listTheoremsExport___closed__3;
lean_ctor_set(x_6, 0, x_24);
return x_6;
}
else
{
lean_object* x_25; lean_object* x_26; lean_object* x_27; 
x_25 = lean_ctor_get(x_23, 0);
lean_inc(x_25);
lean_dec(x_23);
lean_inc(x_2);
x_26 = l_String_toName(x_2);
x_27 = lean_environment_find(x_25, x_26);
if (lean_obj_tag(x_27) == 0)
{
lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; 
x_28 = l_LeanLink_getTypeExport___closed__1;
x_29 = lean_string_append(x_28, x_2);
lean_dec(x_2);
x_30 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_31 = lean_string_append(x_29, x_30);
x_32 = l_WXF_string(x_31);
lean_dec(x_31);
x_33 = l_WXF_header;
x_34 = l_ByteArray_append(x_33, x_32);
lean_dec(x_32);
lean_ctor_set(x_6, 0, x_34);
return x_6;
}
else
{
lean_object* x_35; lean_object* x_36; 
x_35 = lean_ctor_get(x_27, 0);
lean_inc(x_35);
lean_dec(x_27);
x_36 = l_Lean_ConstantInfo_value_x3f(x_35);
if (lean_obj_tag(x_36) == 0)
{
lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; 
x_37 = l_LeanLink_getValueExport___closed__1;
x_38 = lean_string_append(x_37, x_2);
lean_dec(x_2);
x_39 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_40 = lean_string_append(x_38, x_39);
x_41 = l_WXF_string(x_40);
lean_dec(x_40);
x_42 = l_WXF_header;
x_43 = l_ByteArray_append(x_42, x_41);
lean_dec(x_41);
lean_ctor_set(x_6, 0, x_43);
return x_6;
}
else
{
lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; 
lean_dec(x_2);
x_44 = lean_ctor_get(x_36, 0);
lean_inc(x_44);
lean_dec(x_36);
x_45 = lean_uint32_to_nat(x_3);
x_46 = l_WXF_exprToWXF(x_44, x_45);
x_47 = l_WXF_header;
x_48 = l_ByteArray_append(x_47, x_46);
lean_dec(x_46);
lean_ctor_set(x_6, 0, x_48);
return x_6;
}
}
}
}
else
{
lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; uint64_t x_53; uint64_t x_54; uint64_t x_55; uint64_t x_56; uint64_t x_57; uint64_t x_58; size_t x_59; size_t x_60; size_t x_61; size_t x_62; size_t x_63; lean_object* x_64; lean_object* x_65; 
x_49 = lean_ctor_get(x_6, 0);
x_50 = lean_ctor_get(x_6, 1);
lean_inc(x_50);
lean_inc(x_49);
lean_dec(x_6);
x_51 = lean_ctor_get(x_49, 1);
lean_inc(x_51);
lean_dec(x_49);
x_52 = lean_array_get_size(x_51);
x_53 = 32;
x_54 = lean_uint64_shift_right(x_1, x_53);
x_55 = lean_uint64_xor(x_1, x_54);
x_56 = 16;
x_57 = lean_uint64_shift_right(x_55, x_56);
x_58 = lean_uint64_xor(x_55, x_57);
x_59 = lean_uint64_to_usize(x_58);
x_60 = lean_usize_of_nat(x_52);
lean_dec(x_52);
x_61 = 1;
x_62 = lean_usize_sub(x_60, x_61);
x_63 = lean_usize_land(x_59, x_62);
x_64 = lean_array_uget(x_51, x_63);
lean_dec(x_51);
x_65 = l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(x_1, x_64);
if (lean_obj_tag(x_65) == 0)
{
lean_object* x_66; lean_object* x_67; 
lean_dec(x_2);
x_66 = l_LeanLink_listTheoremsExport___closed__3;
x_67 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_67, 0, x_66);
lean_ctor_set(x_67, 1, x_50);
return x_67;
}
else
{
lean_object* x_68; lean_object* x_69; lean_object* x_70; 
x_68 = lean_ctor_get(x_65, 0);
lean_inc(x_68);
lean_dec(x_65);
lean_inc(x_2);
x_69 = l_String_toName(x_2);
x_70 = lean_environment_find(x_68, x_69);
if (lean_obj_tag(x_70) == 0)
{
lean_object* x_71; lean_object* x_72; lean_object* x_73; lean_object* x_74; lean_object* x_75; lean_object* x_76; lean_object* x_77; lean_object* x_78; 
x_71 = l_LeanLink_getTypeExport___closed__1;
x_72 = lean_string_append(x_71, x_2);
lean_dec(x_2);
x_73 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_74 = lean_string_append(x_72, x_73);
x_75 = l_WXF_string(x_74);
lean_dec(x_74);
x_76 = l_WXF_header;
x_77 = l_ByteArray_append(x_76, x_75);
lean_dec(x_75);
x_78 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_78, 0, x_77);
lean_ctor_set(x_78, 1, x_50);
return x_78;
}
else
{
lean_object* x_79; lean_object* x_80; 
x_79 = lean_ctor_get(x_70, 0);
lean_inc(x_79);
lean_dec(x_70);
x_80 = l_Lean_ConstantInfo_value_x3f(x_79);
if (lean_obj_tag(x_80) == 0)
{
lean_object* x_81; lean_object* x_82; lean_object* x_83; lean_object* x_84; lean_object* x_85; lean_object* x_86; lean_object* x_87; lean_object* x_88; 
x_81 = l_LeanLink_getValueExport___closed__1;
x_82 = lean_string_append(x_81, x_2);
lean_dec(x_2);
x_83 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_84 = lean_string_append(x_82, x_83);
x_85 = l_WXF_string(x_84);
lean_dec(x_84);
x_86 = l_WXF_header;
x_87 = l_ByteArray_append(x_86, x_85);
lean_dec(x_85);
x_88 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_88, 0, x_87);
lean_ctor_set(x_88, 1, x_50);
return x_88;
}
else
{
lean_object* x_89; lean_object* x_90; lean_object* x_91; lean_object* x_92; lean_object* x_93; lean_object* x_94; 
lean_dec(x_2);
x_89 = lean_ctor_get(x_80, 0);
lean_inc(x_89);
lean_dec(x_80);
x_90 = lean_uint32_to_nat(x_3);
x_91 = l_WXF_exprToWXF(x_89, x_90);
x_92 = l_WXF_header;
x_93 = l_ByteArray_append(x_92, x_91);
lean_dec(x_91);
x_94 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_94, 0, x_93);
lean_ctor_set(x_94, 1, x_50);
return x_94;
}
}
}
}
}
}
LEAN_EXPORT lean_object* l_LeanLink_getValueExport___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint64_t x_5; uint32_t x_6; lean_object* x_7; 
x_5 = lean_unbox_uint64(x_1);
lean_dec(x_1);
x_6 = lean_unbox_uint32(x_3);
lean_dec(x_3);
x_7 = leanlink_get_value(x_5, x_2, x_6, x_4);
return x_7;
}
}
LEAN_EXPORT lean_object* leanlink_get_constant(uint64_t x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; uint8_t x_6; 
x_4 = l_LeanLink_loadEnvExport___closed__2;
x_5 = lean_st_ref_get(x_4, x_3);
x_6 = !lean_is_exclusive(x_5);
if (x_6 == 0)
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; uint64_t x_10; uint64_t x_11; uint64_t x_12; uint64_t x_13; uint64_t x_14; uint64_t x_15; size_t x_16; size_t x_17; size_t x_18; size_t x_19; size_t x_20; lean_object* x_21; lean_object* x_22; 
x_7 = lean_ctor_get(x_5, 0);
x_8 = lean_ctor_get(x_7, 1);
lean_inc(x_8);
lean_dec(x_7);
x_9 = lean_array_get_size(x_8);
x_10 = 32;
x_11 = lean_uint64_shift_right(x_1, x_10);
x_12 = lean_uint64_xor(x_1, x_11);
x_13 = 16;
x_14 = lean_uint64_shift_right(x_12, x_13);
x_15 = lean_uint64_xor(x_12, x_14);
x_16 = lean_uint64_to_usize(x_15);
x_17 = lean_usize_of_nat(x_9);
lean_dec(x_9);
x_18 = 1;
x_19 = lean_usize_sub(x_17, x_18);
x_20 = lean_usize_land(x_16, x_19);
x_21 = lean_array_uget(x_8, x_20);
lean_dec(x_8);
x_22 = l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(x_1, x_21);
if (lean_obj_tag(x_22) == 0)
{
lean_object* x_23; 
lean_dec(x_2);
x_23 = l_LeanLink_listTheoremsExport___closed__3;
lean_ctor_set(x_5, 0, x_23);
return x_5;
}
else
{
lean_object* x_24; lean_object* x_25; lean_object* x_26; 
x_24 = lean_ctor_get(x_22, 0);
lean_inc(x_24);
lean_dec(x_22);
lean_inc(x_2);
x_25 = l_String_toName(x_2);
x_26 = lean_environment_find(x_24, x_25);
if (lean_obj_tag(x_26) == 0)
{
lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; 
x_27 = l_LeanLink_getTypeExport___closed__1;
x_28 = lean_string_append(x_27, x_2);
lean_dec(x_2);
x_29 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_30 = lean_string_append(x_28, x_29);
x_31 = l_WXF_string(x_30);
lean_dec(x_30);
x_32 = l_WXF_header;
x_33 = l_ByteArray_append(x_32, x_31);
lean_dec(x_31);
lean_ctor_set(x_5, 0, x_33);
return x_5;
}
else
{
lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; 
lean_dec(x_2);
x_34 = lean_ctor_get(x_26, 0);
lean_inc(x_34);
lean_dec(x_26);
x_35 = l_WXF_constantToWXF(x_34);
x_36 = l_WXF_header;
x_37 = l_ByteArray_append(x_36, x_35);
lean_dec(x_35);
lean_ctor_set(x_5, 0, x_37);
return x_5;
}
}
}
else
{
lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; uint64_t x_42; uint64_t x_43; uint64_t x_44; uint64_t x_45; uint64_t x_46; uint64_t x_47; size_t x_48; size_t x_49; size_t x_50; size_t x_51; size_t x_52; lean_object* x_53; lean_object* x_54; 
x_38 = lean_ctor_get(x_5, 0);
x_39 = lean_ctor_get(x_5, 1);
lean_inc(x_39);
lean_inc(x_38);
lean_dec(x_5);
x_40 = lean_ctor_get(x_38, 1);
lean_inc(x_40);
lean_dec(x_38);
x_41 = lean_array_get_size(x_40);
x_42 = 32;
x_43 = lean_uint64_shift_right(x_1, x_42);
x_44 = lean_uint64_xor(x_1, x_43);
x_45 = 16;
x_46 = lean_uint64_shift_right(x_44, x_45);
x_47 = lean_uint64_xor(x_44, x_46);
x_48 = lean_uint64_to_usize(x_47);
x_49 = lean_usize_of_nat(x_41);
lean_dec(x_41);
x_50 = 1;
x_51 = lean_usize_sub(x_49, x_50);
x_52 = lean_usize_land(x_48, x_51);
x_53 = lean_array_uget(x_40, x_52);
lean_dec(x_40);
x_54 = l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(x_1, x_53);
if (lean_obj_tag(x_54) == 0)
{
lean_object* x_55; lean_object* x_56; 
lean_dec(x_2);
x_55 = l_LeanLink_listTheoremsExport___closed__3;
x_56 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_56, 0, x_55);
lean_ctor_set(x_56, 1, x_39);
return x_56;
}
else
{
lean_object* x_57; lean_object* x_58; lean_object* x_59; 
x_57 = lean_ctor_get(x_54, 0);
lean_inc(x_57);
lean_dec(x_54);
lean_inc(x_2);
x_58 = l_String_toName(x_2);
x_59 = lean_environment_find(x_57, x_58);
if (lean_obj_tag(x_59) == 0)
{
lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; 
x_60 = l_LeanLink_getTypeExport___closed__1;
x_61 = lean_string_append(x_60, x_2);
lean_dec(x_2);
x_62 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_63 = lean_string_append(x_61, x_62);
x_64 = l_WXF_string(x_63);
lean_dec(x_63);
x_65 = l_WXF_header;
x_66 = l_ByteArray_append(x_65, x_64);
lean_dec(x_64);
x_67 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_67, 0, x_66);
lean_ctor_set(x_67, 1, x_39);
return x_67;
}
else
{
lean_object* x_68; lean_object* x_69; lean_object* x_70; lean_object* x_71; lean_object* x_72; 
lean_dec(x_2);
x_68 = lean_ctor_get(x_59, 0);
lean_inc(x_68);
lean_dec(x_59);
x_69 = l_WXF_constantToWXF(x_68);
x_70 = l_WXF_header;
x_71 = l_ByteArray_append(x_70, x_69);
lean_dec(x_69);
x_72 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_72, 0, x_71);
lean_ctor_set(x_72, 1, x_39);
return x_72;
}
}
}
}
}
LEAN_EXPORT lean_object* l_LeanLink_getConstantExport___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
uint64_t x_4; lean_object* x_5; 
x_4 = lean_unbox_uint64(x_1);
lean_dec(x_1);
x_5 = leanlink_get_constant(x_4, x_2, x_3);
return x_5;
}
}
LEAN_EXPORT lean_object* l_Array_mapMUnsafe_map___at_LeanLink_getUsedConstantsExport___spec__1(size_t x_1, size_t x_2, lean_object* x_3) {
_start:
{
uint8_t x_4; 
x_4 = lean_usize_dec_lt(x_2, x_1);
if (x_4 == 0)
{
return x_3;
}
else
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; uint8_t x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; size_t x_12; size_t x_13; lean_object* x_14; 
x_5 = lean_array_uget(x_3, x_2);
x_6 = lean_unsigned_to_nat(0u);
x_7 = lean_array_uset(x_3, x_2, x_6);
x_8 = 1;
x_9 = l_LeanLink_listTheoremsExport___lambda__2___closed__1;
x_10 = l_Lean_Name_toString(x_5, x_8, x_9);
x_11 = l_WXF_string(x_10);
lean_dec(x_10);
x_12 = 1;
x_13 = lean_usize_add(x_2, x_12);
x_14 = lean_array_uset(x_7, x_2, x_11);
x_2 = x_13;
x_3 = x_14;
goto _start;
}
}
}
LEAN_EXPORT lean_object* l_Lean_RBNode_fold___at_LeanLink_getUsedConstantsExport___spec__2(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
if (lean_obj_tag(x_4) == 0)
{
return x_3;
}
else
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; uint8_t x_9; 
x_5 = lean_ctor_get(x_4, 0);
lean_inc(x_5);
x_6 = lean_ctor_get(x_4, 1);
lean_inc(x_6);
x_7 = lean_ctor_get(x_4, 3);
lean_inc(x_7);
lean_dec(x_4);
x_8 = l_Lean_RBNode_fold___at_LeanLink_getUsedConstantsExport___spec__2(x_1, x_2, x_3, x_5);
x_9 = l_Lean_NameHashSet_contains(x_1, x_6);
if (x_9 == 0)
{
uint8_t x_10; 
x_10 = l_Lean_NameHashSet_contains(x_2, x_6);
if (x_10 == 0)
{
uint8_t x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; 
x_11 = 1;
x_12 = l_LeanLink_listTheoremsExport___lambda__2___closed__1;
x_13 = l_Lean_Name_toString(x_6, x_11, x_12);
x_14 = l_WXF_string(x_13);
lean_dec(x_13);
x_15 = lean_array_push(x_8, x_14);
x_3 = x_15;
x_4 = x_7;
goto _start;
}
else
{
lean_dec(x_6);
x_3 = x_8;
x_4 = x_7;
goto _start;
}
}
else
{
lean_dec(x_6);
x_3 = x_8;
x_4 = x_7;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* l_Array_foldlMUnsafe_fold___at_LeanLink_getUsedConstantsExport___spec__3(lean_object* x_1, size_t x_2, size_t x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; 
x_5 = lean_usize_dec_eq(x_2, x_3);
if (x_5 == 0)
{
lean_object* x_6; lean_object* x_7; size_t x_8; size_t x_9; 
x_6 = lean_array_uget(x_1, x_2);
x_7 = l_Lean_NameHashSet_insert(x_4, x_6);
x_8 = 1;
x_9 = lean_usize_add(x_2, x_8);
x_2 = x_9;
x_4 = x_7;
goto _start;
}
else
{
return x_4;
}
}
}
static lean_object* _init_l_LeanLink_getUsedConstantsExport___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("type", 4, 4);
return x_1;
}
}
static lean_object* _init_l_LeanLink_getUsedConstantsExport___closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = l_LeanLink_getUsedConstantsExport___closed__1;
x_2 = l_WXF_string(x_1);
return x_2;
}
}
static lean_object* _init_l_LeanLink_getUsedConstantsExport___closed__3() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("value", 5, 5);
return x_1;
}
}
static lean_object* _init_l_LeanLink_getUsedConstantsExport___closed__4() {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = l_LeanLink_getUsedConstantsExport___closed__3;
x_2 = l_WXF_string(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* leanlink_get_used_constants(uint64_t x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; uint8_t x_9; 
x_4 = l_LeanLink_loadEnvExport___closed__2;
x_5 = lean_st_ref_get(x_4, x_3);
x_6 = lean_ctor_get(x_5, 0);
lean_inc(x_6);
x_7 = lean_ctor_get(x_5, 1);
lean_inc(x_7);
if (lean_is_exclusive(x_5)) {
 lean_ctor_release(x_5, 0);
 lean_ctor_release(x_5, 1);
 x_8 = x_5;
} else {
 lean_dec_ref(x_5);
 x_8 = lean_box(0);
}
x_9 = !lean_is_exclusive(x_6);
if (x_9 == 0)
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; uint64_t x_13; uint64_t x_14; uint64_t x_15; uint64_t x_16; uint64_t x_17; uint64_t x_18; size_t x_19; size_t x_20; size_t x_21; size_t x_22; size_t x_23; lean_object* x_24; lean_object* x_25; 
x_10 = lean_ctor_get(x_6, 1);
x_11 = lean_ctor_get(x_6, 0);
lean_dec(x_11);
x_12 = lean_array_get_size(x_10);
x_13 = 32;
x_14 = lean_uint64_shift_right(x_1, x_13);
x_15 = lean_uint64_xor(x_1, x_14);
x_16 = 16;
x_17 = lean_uint64_shift_right(x_15, x_16);
x_18 = lean_uint64_xor(x_15, x_17);
x_19 = lean_uint64_to_usize(x_18);
x_20 = lean_usize_of_nat(x_12);
lean_dec(x_12);
x_21 = 1;
x_22 = lean_usize_sub(x_20, x_21);
x_23 = lean_usize_land(x_19, x_22);
x_24 = lean_array_uget(x_10, x_23);
lean_dec(x_10);
x_25 = l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(x_1, x_24);
if (lean_obj_tag(x_25) == 0)
{
lean_object* x_26; lean_object* x_27; 
lean_free_object(x_6);
lean_dec(x_2);
x_26 = l_LeanLink_listTheoremsExport___closed__3;
if (lean_is_scalar(x_8)) {
 x_27 = lean_alloc_ctor(0, 2, 0);
} else {
 x_27 = x_8;
}
lean_ctor_set(x_27, 0, x_26);
lean_ctor_set(x_27, 1, x_7);
return x_27;
}
else
{
lean_object* x_28; lean_object* x_29; lean_object* x_30; 
x_28 = lean_ctor_get(x_25, 0);
lean_inc(x_28);
lean_dec(x_25);
lean_inc(x_2);
x_29 = l_String_toName(x_2);
x_30 = lean_environment_find(x_28, x_29);
if (lean_obj_tag(x_30) == 0)
{
lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; 
lean_free_object(x_6);
x_31 = l_LeanLink_getTypeExport___closed__1;
x_32 = lean_string_append(x_31, x_2);
lean_dec(x_2);
x_33 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_34 = lean_string_append(x_32, x_33);
x_35 = l_WXF_string(x_34);
lean_dec(x_34);
x_36 = l_WXF_header;
x_37 = l_ByteArray_append(x_36, x_35);
lean_dec(x_35);
if (lean_is_scalar(x_8)) {
 x_38 = lean_alloc_ctor(0, 2, 0);
} else {
 x_38 = x_8;
}
lean_ctor_set(x_38, 0, x_37);
lean_ctor_set(x_38, 1, x_7);
return x_38;
}
else
{
lean_object* x_39; lean_object* x_40; lean_object* x_41; size_t x_42; size_t x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; uint8_t x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; lean_object* x_53; 
lean_dec(x_2);
x_39 = lean_ctor_get(x_30, 0);
lean_inc(x_39);
lean_dec(x_30);
x_40 = l_Lean_ConstantInfo_type(x_39);
x_41 = l_Lean_Expr_getUsedConstants(x_40);
x_42 = lean_array_size(x_41);
x_43 = 0;
lean_inc(x_41);
x_44 = l_Array_mapMUnsafe_map___at_LeanLink_getUsedConstantsExport___spec__1(x_42, x_43, x_41);
lean_inc(x_39);
x_45 = l_Lean_ConstantInfo_value_x3f(x_39);
x_46 = l_Lean_ConstantInfo_getUsedConstantsAsSet(x_39);
x_47 = lean_array_get_size(x_41);
x_48 = lean_unsigned_to_nat(0u);
x_49 = lean_nat_dec_lt(x_48, x_47);
x_50 = lean_box(0);
x_51 = l_WXF_wlList(x_44);
lean_dec(x_44);
x_52 = l_LeanLink_getUsedConstantsExport___closed__2;
lean_ctor_set(x_6, 1, x_51);
lean_ctor_set(x_6, 0, x_52);
if (lean_obj_tag(x_45) == 0)
{
lean_object* x_88; 
x_88 = l_LeanLink_loadEnvExport___closed__6;
x_53 = x_88;
goto block_87;
}
else
{
lean_object* x_89; lean_object* x_90; 
x_89 = lean_ctor_get(x_45, 0);
lean_inc(x_89);
lean_dec(x_45);
x_90 = l_Lean_Expr_getUsedConstants(x_89);
x_53 = x_90;
goto block_87;
}
block_87:
{
size_t x_54; lean_object* x_55; lean_object* x_56; uint8_t x_57; lean_object* x_58; 
x_54 = lean_array_size(x_53);
lean_inc(x_53);
x_55 = l_Array_mapMUnsafe_map___at_LeanLink_getUsedConstantsExport___spec__1(x_54, x_43, x_53);
x_56 = lean_array_get_size(x_53);
x_57 = lean_nat_dec_lt(x_48, x_56);
if (x_49 == 0)
{
lean_object* x_81; 
lean_dec(x_47);
lean_dec(x_41);
x_81 = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3;
x_58 = x_81;
goto block_80;
}
else
{
uint8_t x_82; 
x_82 = lean_nat_dec_le(x_47, x_47);
if (x_82 == 0)
{
lean_object* x_83; 
lean_dec(x_47);
lean_dec(x_41);
x_83 = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3;
x_58 = x_83;
goto block_80;
}
else
{
size_t x_84; lean_object* x_85; lean_object* x_86; 
x_84 = lean_usize_of_nat(x_47);
lean_dec(x_47);
x_85 = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3;
x_86 = l_Array_foldlMUnsafe_fold___at_LeanLink_getUsedConstantsExport___spec__3(x_41, x_43, x_84, x_85);
lean_dec(x_41);
x_58 = x_86;
goto block_80;
}
}
block_80:
{
lean_object* x_59; 
if (x_57 == 0)
{
lean_object* x_74; 
lean_dec(x_56);
lean_dec(x_53);
x_74 = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3;
x_59 = x_74;
goto block_73;
}
else
{
uint8_t x_75; 
x_75 = lean_nat_dec_le(x_56, x_56);
if (x_75 == 0)
{
lean_object* x_76; 
lean_dec(x_56);
lean_dec(x_53);
x_76 = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3;
x_59 = x_76;
goto block_73;
}
else
{
size_t x_77; lean_object* x_78; lean_object* x_79; 
x_77 = lean_usize_of_nat(x_56);
lean_dec(x_56);
x_78 = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3;
x_79 = l_Array_foldlMUnsafe_fold___at_LeanLink_getUsedConstantsExport___spec__3(x_53, x_43, x_77, x_78);
lean_dec(x_53);
x_59 = x_79;
goto block_73;
}
}
block_73:
{
lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; lean_object* x_69; lean_object* x_70; lean_object* x_71; lean_object* x_72; 
x_60 = l_LeanLink_loadEnvExport___closed__6;
x_61 = l_Lean_RBNode_fold___at_LeanLink_getUsedConstantsExport___spec__2(x_58, x_59, x_60, x_46);
lean_dec(x_59);
lean_dec(x_58);
x_62 = l_Array_append___rarg(x_55, x_61);
lean_dec(x_61);
x_63 = l_WXF_wlList(x_62);
lean_dec(x_62);
x_64 = l_LeanLink_getUsedConstantsExport___closed__4;
x_65 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_65, 0, x_64);
lean_ctor_set(x_65, 1, x_63);
x_66 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_66, 0, x_65);
lean_ctor_set(x_66, 1, x_50);
x_67 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_67, 0, x_6);
lean_ctor_set(x_67, 1, x_66);
x_68 = lean_array_mk(x_67);
x_69 = l_WXF_wlAssociation(x_68);
lean_dec(x_68);
x_70 = l_WXF_header;
x_71 = l_ByteArray_append(x_70, x_69);
lean_dec(x_69);
if (lean_is_scalar(x_8)) {
 x_72 = lean_alloc_ctor(0, 2, 0);
} else {
 x_72 = x_8;
}
lean_ctor_set(x_72, 0, x_71);
lean_ctor_set(x_72, 1, x_7);
return x_72;
}
}
}
}
}
}
else
{
lean_object* x_91; lean_object* x_92; uint64_t x_93; uint64_t x_94; uint64_t x_95; uint64_t x_96; uint64_t x_97; uint64_t x_98; size_t x_99; size_t x_100; size_t x_101; size_t x_102; size_t x_103; lean_object* x_104; lean_object* x_105; 
x_91 = lean_ctor_get(x_6, 1);
lean_inc(x_91);
lean_dec(x_6);
x_92 = lean_array_get_size(x_91);
x_93 = 32;
x_94 = lean_uint64_shift_right(x_1, x_93);
x_95 = lean_uint64_xor(x_1, x_94);
x_96 = 16;
x_97 = lean_uint64_shift_right(x_95, x_96);
x_98 = lean_uint64_xor(x_95, x_97);
x_99 = lean_uint64_to_usize(x_98);
x_100 = lean_usize_of_nat(x_92);
lean_dec(x_92);
x_101 = 1;
x_102 = lean_usize_sub(x_100, x_101);
x_103 = lean_usize_land(x_99, x_102);
x_104 = lean_array_uget(x_91, x_103);
lean_dec(x_91);
x_105 = l_Std_DHashMap_Internal_AssocList_get_x3f___at_LeanLink_listTheoremsExport___spec__1(x_1, x_104);
if (lean_obj_tag(x_105) == 0)
{
lean_object* x_106; lean_object* x_107; 
lean_dec(x_2);
x_106 = l_LeanLink_listTheoremsExport___closed__3;
if (lean_is_scalar(x_8)) {
 x_107 = lean_alloc_ctor(0, 2, 0);
} else {
 x_107 = x_8;
}
lean_ctor_set(x_107, 0, x_106);
lean_ctor_set(x_107, 1, x_7);
return x_107;
}
else
{
lean_object* x_108; lean_object* x_109; lean_object* x_110; 
x_108 = lean_ctor_get(x_105, 0);
lean_inc(x_108);
lean_dec(x_105);
lean_inc(x_2);
x_109 = l_String_toName(x_2);
x_110 = lean_environment_find(x_108, x_109);
if (lean_obj_tag(x_110) == 0)
{
lean_object* x_111; lean_object* x_112; lean_object* x_113; lean_object* x_114; lean_object* x_115; lean_object* x_116; lean_object* x_117; lean_object* x_118; 
x_111 = l_LeanLink_getTypeExport___closed__1;
x_112 = lean_string_append(x_111, x_2);
lean_dec(x_2);
x_113 = l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1;
x_114 = lean_string_append(x_112, x_113);
x_115 = l_WXF_string(x_114);
lean_dec(x_114);
x_116 = l_WXF_header;
x_117 = l_ByteArray_append(x_116, x_115);
lean_dec(x_115);
if (lean_is_scalar(x_8)) {
 x_118 = lean_alloc_ctor(0, 2, 0);
} else {
 x_118 = x_8;
}
lean_ctor_set(x_118, 0, x_117);
lean_ctor_set(x_118, 1, x_7);
return x_118;
}
else
{
lean_object* x_119; lean_object* x_120; lean_object* x_121; size_t x_122; size_t x_123; lean_object* x_124; lean_object* x_125; lean_object* x_126; lean_object* x_127; lean_object* x_128; uint8_t x_129; lean_object* x_130; lean_object* x_131; lean_object* x_132; lean_object* x_133; lean_object* x_134; 
lean_dec(x_2);
x_119 = lean_ctor_get(x_110, 0);
lean_inc(x_119);
lean_dec(x_110);
x_120 = l_Lean_ConstantInfo_type(x_119);
x_121 = l_Lean_Expr_getUsedConstants(x_120);
x_122 = lean_array_size(x_121);
x_123 = 0;
lean_inc(x_121);
x_124 = l_Array_mapMUnsafe_map___at_LeanLink_getUsedConstantsExport___spec__1(x_122, x_123, x_121);
lean_inc(x_119);
x_125 = l_Lean_ConstantInfo_value_x3f(x_119);
x_126 = l_Lean_ConstantInfo_getUsedConstantsAsSet(x_119);
x_127 = lean_array_get_size(x_121);
x_128 = lean_unsigned_to_nat(0u);
x_129 = lean_nat_dec_lt(x_128, x_127);
x_130 = lean_box(0);
x_131 = l_WXF_wlList(x_124);
lean_dec(x_124);
x_132 = l_LeanLink_getUsedConstantsExport___closed__2;
x_133 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_133, 0, x_132);
lean_ctor_set(x_133, 1, x_131);
if (lean_obj_tag(x_125) == 0)
{
lean_object* x_169; 
x_169 = l_LeanLink_loadEnvExport___closed__6;
x_134 = x_169;
goto block_168;
}
else
{
lean_object* x_170; lean_object* x_171; 
x_170 = lean_ctor_get(x_125, 0);
lean_inc(x_170);
lean_dec(x_125);
x_171 = l_Lean_Expr_getUsedConstants(x_170);
x_134 = x_171;
goto block_168;
}
block_168:
{
size_t x_135; lean_object* x_136; lean_object* x_137; uint8_t x_138; lean_object* x_139; 
x_135 = lean_array_size(x_134);
lean_inc(x_134);
x_136 = l_Array_mapMUnsafe_map___at_LeanLink_getUsedConstantsExport___spec__1(x_135, x_123, x_134);
x_137 = lean_array_get_size(x_134);
x_138 = lean_nat_dec_lt(x_128, x_137);
if (x_129 == 0)
{
lean_object* x_162; 
lean_dec(x_127);
lean_dec(x_121);
x_162 = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3;
x_139 = x_162;
goto block_161;
}
else
{
uint8_t x_163; 
x_163 = lean_nat_dec_le(x_127, x_127);
if (x_163 == 0)
{
lean_object* x_164; 
lean_dec(x_127);
lean_dec(x_121);
x_164 = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3;
x_139 = x_164;
goto block_161;
}
else
{
size_t x_165; lean_object* x_166; lean_object* x_167; 
x_165 = lean_usize_of_nat(x_127);
lean_dec(x_127);
x_166 = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3;
x_167 = l_Array_foldlMUnsafe_fold___at_LeanLink_getUsedConstantsExport___spec__3(x_121, x_123, x_165, x_166);
lean_dec(x_121);
x_139 = x_167;
goto block_161;
}
}
block_161:
{
lean_object* x_140; 
if (x_138 == 0)
{
lean_object* x_155; 
lean_dec(x_137);
lean_dec(x_134);
x_155 = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3;
x_140 = x_155;
goto block_154;
}
else
{
uint8_t x_156; 
x_156 = lean_nat_dec_le(x_137, x_137);
if (x_156 == 0)
{
lean_object* x_157; 
lean_dec(x_137);
lean_dec(x_134);
x_157 = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3;
x_140 = x_157;
goto block_154;
}
else
{
size_t x_158; lean_object* x_159; lean_object* x_160; 
x_158 = lean_usize_of_nat(x_137);
lean_dec(x_137);
x_159 = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3;
x_160 = l_Array_foldlMUnsafe_fold___at_LeanLink_getUsedConstantsExport___spec__3(x_134, x_123, x_158, x_159);
lean_dec(x_134);
x_140 = x_160;
goto block_154;
}
}
block_154:
{
lean_object* x_141; lean_object* x_142; lean_object* x_143; lean_object* x_144; lean_object* x_145; lean_object* x_146; lean_object* x_147; lean_object* x_148; lean_object* x_149; lean_object* x_150; lean_object* x_151; lean_object* x_152; lean_object* x_153; 
x_141 = l_LeanLink_loadEnvExport___closed__6;
x_142 = l_Lean_RBNode_fold___at_LeanLink_getUsedConstantsExport___spec__2(x_139, x_140, x_141, x_126);
lean_dec(x_140);
lean_dec(x_139);
x_143 = l_Array_append___rarg(x_136, x_142);
lean_dec(x_142);
x_144 = l_WXF_wlList(x_143);
lean_dec(x_143);
x_145 = l_LeanLink_getUsedConstantsExport___closed__4;
x_146 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_146, 0, x_145);
lean_ctor_set(x_146, 1, x_144);
x_147 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_147, 0, x_146);
lean_ctor_set(x_147, 1, x_130);
x_148 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_148, 0, x_133);
lean_ctor_set(x_148, 1, x_147);
x_149 = lean_array_mk(x_148);
x_150 = l_WXF_wlAssociation(x_149);
lean_dec(x_149);
x_151 = l_WXF_header;
x_152 = l_ByteArray_append(x_151, x_150);
lean_dec(x_150);
if (lean_is_scalar(x_8)) {
 x_153 = lean_alloc_ctor(0, 2, 0);
} else {
 x_153 = x_8;
}
lean_ctor_set(x_153, 0, x_152);
lean_ctor_set(x_153, 1, x_7);
return x_153;
}
}
}
}
}
}
}
}
LEAN_EXPORT lean_object* l_Array_mapMUnsafe_map___at_LeanLink_getUsedConstantsExport___spec__1___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
size_t x_4; size_t x_5; lean_object* x_6; 
x_4 = lean_unbox_usize(x_1);
lean_dec(x_1);
x_5 = lean_unbox_usize(x_2);
lean_dec(x_2);
x_6 = l_Array_mapMUnsafe_map___at_LeanLink_getUsedConstantsExport___spec__1(x_4, x_5, x_3);
return x_6;
}
}
LEAN_EXPORT lean_object* l_Lean_RBNode_fold___at_LeanLink_getUsedConstantsExport___spec__2___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = l_Lean_RBNode_fold___at_LeanLink_getUsedConstantsExport___spec__2(x_1, x_2, x_3, x_4);
lean_dec(x_2);
lean_dec(x_1);
return x_5;
}
}
LEAN_EXPORT lean_object* l_Array_foldlMUnsafe_fold___at_LeanLink_getUsedConstantsExport___spec__3___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
size_t x_5; size_t x_6; lean_object* x_7; 
x_5 = lean_unbox_usize(x_2);
lean_dec(x_2);
x_6 = lean_unbox_usize(x_3);
lean_dec(x_3);
x_7 = l_Array_foldlMUnsafe_fold___at_LeanLink_getUsedConstantsExport___spec__3(x_1, x_5, x_6, x_4);
lean_dec(x_1);
return x_7;
}
}
LEAN_EXPORT lean_object* l_LeanLink_getUsedConstantsExport___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
uint64_t x_4; lean_object* x_5; 
x_4 = lean_unbox_uint64(x_1);
lean_dec(x_1);
x_5 = leanlink_get_used_constants(x_4, x_2, x_3);
return x_5;
}
}
lean_object* initialize_Init(uint8_t builtin, lean_object*);
lean_object* initialize_Lean(uint8_t builtin, lean_object*);
lean_object* initialize_LeanLink_WXF(uint8_t builtin, lean_object*);
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_LeanLink_EnvStore(uint8_t builtin, lean_object* w) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
res = initialize_Init(builtin, lean_io_mk_world());
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_Lean(builtin, lean_io_mk_world());
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_LeanLink_WXF(builtin, lean_io_mk_world());
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__1 = _init_l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__1();
lean_mark_persistent(l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__1);
l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__2 = _init_l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__2();
lean_mark_persistent(l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__2);
l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3 = _init_l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3();
lean_mark_persistent(l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5____closed__3);
res = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_5_(lean_io_mk_world());
if (lean_io_result_is_error(res)) return res;
l___private_LeanLink_EnvStore_0__LeanLink_envStore = lean_io_result_get_value(res);
lean_mark_persistent(l___private_LeanLink_EnvStore_0__LeanLink_envStore);
lean_dec_ref(res);
l_LeanLink_initFn___boxed__const__1____x40_LeanLink_EnvStore___hyg_48_ = _init_l_LeanLink_initFn___boxed__const__1____x40_LeanLink_EnvStore___hyg_48_();
lean_mark_persistent(l_LeanLink_initFn___boxed__const__1____x40_LeanLink_EnvStore___hyg_48_);
res = l_LeanLink_initFn____x40_LeanLink_EnvStore___hyg_48_(lean_io_mk_world());
if (lean_io_result_is_error(res)) return res;
l___private_LeanLink_EnvStore_0__LeanLink_nextHandle = lean_io_result_get_value(res);
lean_mark_persistent(l___private_LeanLink_EnvStore_0__LeanLink_nextHandle);
lean_dec_ref(res);
l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1 = _init_l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1();
lean_mark_persistent(l_List_filterTR_loop___at_LeanLink_loadEnv___spec__1___closed__1);
l_LeanLink_loadEnv___closed__1 = _init_l_LeanLink_loadEnv___closed__1();
lean_mark_persistent(l_LeanLink_loadEnv___closed__1);
l_LeanLink_loadEnv___closed__2 = _init_l_LeanLink_loadEnv___closed__2();
l_LeanLink_loadEnv___closed__3 = _init_l_LeanLink_loadEnv___closed__3();
lean_mark_persistent(l_LeanLink_loadEnv___closed__3);
l_LeanLink_loadEnv___closed__4 = _init_l_LeanLink_loadEnv___closed__4();
lean_mark_persistent(l_LeanLink_loadEnv___closed__4);
l_LeanLink_loadEnv___closed__5 = _init_l_LeanLink_loadEnv___closed__5();
lean_mark_persistent(l_LeanLink_loadEnv___closed__5);
l_LeanLink_loadEnv___closed__6 = _init_l_LeanLink_loadEnv___closed__6();
lean_mark_persistent(l_LeanLink_loadEnv___closed__6);
l_LeanLink_loadEnv___closed__7 = _init_l_LeanLink_loadEnv___closed__7();
lean_mark_persistent(l_LeanLink_loadEnv___closed__7);
l_LeanLink_initLeanLink___boxed__const__1 = _init_l_LeanLink_initLeanLink___boxed__const__1();
lean_mark_persistent(l_LeanLink_initLeanLink___boxed__const__1);
l_LeanLink_loadEnvExport___closed__1 = _init_l_LeanLink_loadEnvExport___closed__1();
lean_mark_persistent(l_LeanLink_loadEnvExport___closed__1);
l_LeanLink_loadEnvExport___closed__2 = _init_l_LeanLink_loadEnvExport___closed__2();
lean_mark_persistent(l_LeanLink_loadEnvExport___closed__2);
l_LeanLink_loadEnvExport___closed__3 = _init_l_LeanLink_loadEnvExport___closed__3();
lean_mark_persistent(l_LeanLink_loadEnvExport___closed__3);
l_LeanLink_loadEnvExport___closed__4 = _init_l_LeanLink_loadEnvExport___closed__4();
lean_mark_persistent(l_LeanLink_loadEnvExport___closed__4);
l_LeanLink_loadEnvExport___closed__5 = _init_l_LeanLink_loadEnvExport___closed__5();
l_LeanLink_loadEnvExport___closed__6 = _init_l_LeanLink_loadEnvExport___closed__6();
lean_mark_persistent(l_LeanLink_loadEnvExport___closed__6);
l_LeanLink_loadEnvExport___boxed__const__1 = _init_l_LeanLink_loadEnvExport___boxed__const__1();
lean_mark_persistent(l_LeanLink_loadEnvExport___boxed__const__1);
l_LeanLink_listTheoremsExport___lambda__2___closed__1 = _init_l_LeanLink_listTheoremsExport___lambda__2___closed__1();
lean_mark_persistent(l_LeanLink_listTheoremsExport___lambda__2___closed__1);
l_LeanLink_listTheoremsExport___closed__1 = _init_l_LeanLink_listTheoremsExport___closed__1();
lean_mark_persistent(l_LeanLink_listTheoremsExport___closed__1);
l_LeanLink_listTheoremsExport___closed__2 = _init_l_LeanLink_listTheoremsExport___closed__2();
lean_mark_persistent(l_LeanLink_listTheoremsExport___closed__2);
l_LeanLink_listTheoremsExport___closed__3 = _init_l_LeanLink_listTheoremsExport___closed__3();
lean_mark_persistent(l_LeanLink_listTheoremsExport___closed__3);
l_LeanLink_getTypeExport___closed__1 = _init_l_LeanLink_getTypeExport___closed__1();
lean_mark_persistent(l_LeanLink_getTypeExport___closed__1);
l_LeanLink_getValueExport___closed__1 = _init_l_LeanLink_getValueExport___closed__1();
lean_mark_persistent(l_LeanLink_getValueExport___closed__1);
l_LeanLink_getUsedConstantsExport___closed__1 = _init_l_LeanLink_getUsedConstantsExport___closed__1();
lean_mark_persistent(l_LeanLink_getUsedConstantsExport___closed__1);
l_LeanLink_getUsedConstantsExport___closed__2 = _init_l_LeanLink_getUsedConstantsExport___closed__2();
lean_mark_persistent(l_LeanLink_getUsedConstantsExport___closed__2);
l_LeanLink_getUsedConstantsExport___closed__3 = _init_l_LeanLink_getUsedConstantsExport___closed__3();
lean_mark_persistent(l_LeanLink_getUsedConstantsExport___closed__3);
l_LeanLink_getUsedConstantsExport___closed__4 = _init_l_LeanLink_getUsedConstantsExport___closed__4();
lean_mark_persistent(l_LeanLink_getUsedConstantsExport___closed__4);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
