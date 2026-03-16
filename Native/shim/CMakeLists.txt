cmake_minimum_required(VERSION 3.20)
project(LeanLinkShim C)

# --- Lean SDK ---
set(LEAN_HOME "$ENV{HOME}/.elan/toolchains/leanprover--lean4---v4.29.0-rc6")

# --- Wolfram LibraryLink ---
set(WL_INCLUDE "/Applications/Wolfram 15.0.app/Contents/SystemFiles/IncludeFiles/C")

# --- Generated IR from Lake build ---
set(NATIVE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/..")
set(IR_DIR "${NATIVE_DIR}/.lake/build/ir")

# Shim shared library
add_library(LeanLinkShim SHARED
    leanlink_shim.c
    ${IR_DIR}/LeanLink.c
    ${IR_DIR}/LeanLink/WXF.c
    ${IR_DIR}/LeanLink/EnvStore.c
    ${IR_DIR}/LeanLink/Examples.c
)

# Pass Lean library path at compile time for LEAN_PATH init
target_compile_definitions(LeanLinkShim PRIVATE
    LEAN_LIB_DIR="${LEAN_HOME}/lib/lean"
)

target_include_directories(LeanLinkShim PRIVATE
    ${LEAN_HOME}/include
    ${WL_INCLUDE}
)

target_link_directories(LeanLinkShim PRIVATE ${LEAN_HOME}/lib/lean)
target_link_libraries(LeanLinkShim PRIVATE leanshared)

# Fix @rpath/libleanshared.dylib to absolute path for WolframKernel compatibility
add_custom_command(TARGET LeanLinkShim POST_BUILD
    COMMAND install_name_tool -change @rpath/libleanshared.dylib
        ${LEAN_HOME}/lib/lean/libleanshared.dylib $<TARGET_FILE:LeanLinkShim>
    COMMENT "Fixing libleanshared.dylib path for WolframKernel"
)

# Standalone test
add_executable(test_lean_proper test_lean_proper.c
    ${IR_DIR}/LeanLink.c
    ${IR_DIR}/LeanLink/WXF.c
    ${IR_DIR}/LeanLink/EnvStore.c
    ${IR_DIR}/LeanLink/Examples.c
)
target_include_directories(test_lean_proper PRIVATE ${LEAN_HOME}/include)
target_link_directories(test_lean_proper PRIVATE ${LEAN_HOME}/lib/lean)
target_link_libraries(test_lean_proper PRIVATE leanshared)

# Full tactic test (identity + constructor)
add_executable(test_full_tactic test_full_tactic.c
    ${IR_DIR}/LeanLink.c
    ${IR_DIR}/LeanLink/WXF.c
    ${IR_DIR}/LeanLink/EnvStore.c
    ${IR_DIR}/LeanLink/Examples.c
)
target_include_directories(test_full_tactic PRIVATE ${LEAN_HOME}/include)
target_link_directories(test_full_tactic PRIVATE ${LEAN_HOME}/lib/lean)
target_link_libraries(test_full_tactic PRIVATE leanshared)
