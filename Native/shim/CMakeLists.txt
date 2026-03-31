cmake_minimum_required(VERSION 3.20)
project(LeanLinkShim C)

# --- Lean SDK ---
set(LEAN_HOME "$ENV{HOME}/.elan/toolchains/leanprover--lean4---v4.29.0-rc6" CACHE PATH "Path to Lean installation")

# --- Wolfram LibraryLink ---
set(WL_INCLUDE "/Applications/Wolfram 15.0.app/Contents/SystemFiles/IncludeFiles/C" CACHE PATH "Path to Wolfram LibraryLink headers")

# --- Generated IR from Lake build ---
set(NATIVE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/..")
set(IR_DIR "${NATIVE_DIR}/.lake/build/ir")

# --- Paclet LibraryResources output ---
set(PACLET_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../LeanLink")
if(NOT DEFINED WL_SYSID)
    if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
        if(CMAKE_SYSTEM_PROCESSOR STREQUAL "arm64" OR CMAKE_OSX_ARCHITECTURES STREQUAL "arm64")
            set(WL_SYSID "MacOSX-ARM64")
        else()
            set(WL_SYSID "MacOSX-x86-64")
        endif()
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        if(CMAKE_SYSTEM_PROCESSOR STREQUAL "aarch64")
            set(WL_SYSID "Linux-ARM64")
        else()
            set(WL_SYSID "Linux-x86-64")
        endif()
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
        set(WL_SYSID "Windows-x86-64")
    endif()
endif()

set(LIB_RES_DIR "${PACLET_DIR}/LibraryResources/${WL_SYSID}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${LIB_RES_DIR}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${LIB_RES_DIR}")

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
if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(DEFAULT_LIBS ${CMAKE_SOURCE_DIR}/libgnu_lean_thunks.a ${LEAN_HOME}/bin/libleanshared.dll ${LEAN_HOME}/bin/libleanshared_1.dll ${LEAN_HOME}/bin/libleanshared_2.dll)
    target_link_libraries(LeanLinkShim PRIVATE -Wl,--enable-auto-import ${DEFAULT_LIBS})
else()
    target_link_libraries(LeanLinkShim PRIVATE leanshared)
endif()

# Post-build: fix dylib paths (macOS) and copy libleanshared
if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    add_custom_command(TARGET LeanLinkShim POST_BUILD
        COMMAND install_name_tool -change @rpath/libleanshared.dylib
            ${LEAN_HOME}/lib/lean/libleanshared.dylib $<TARGET_FILE:LeanLinkShim>
        COMMENT "Fixing libleanshared.dylib path for WolframKernel"
    )
endif()

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
