cmake_minimum_required(VERSION 3.23)

# Pin the compiler. Both GCC 16.2.1 and Clang 23.1.3 are installed here, and a
# number produced by one is not a number produced by the other. Clang is the
# project compiler because llvm-mca comes from the same toolchain.
# Must be set before project(), which is where CMake fixes the compiler.
if(NOT CMAKE_CXX_COMPILER)
    set(CMAKE_CXX_COMPILER clang++ CACHE FILEPATH "C++ compiler")
endif()
if(NOT CMAKE_C_COMPILER)
    set(CMAKE_C_COMPILER clang CACHE FILEPATH "C compiler")
endif()

project(lobster LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Export compile_commands.json so clangd works without extra flags.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Default to a build type, otherwise CMake builds with no optimisation
# and no debug info at all.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

add_library(lobster_core src/store.cpp)
add_executable(lobster src/main.cpp)
target_link_libraries(lobster PRIVATE lobster_core)

target_compile_options(lobster PRIVATE -Wall -Wextra -Wpedantic)
enable_testing()

add_subdirectory(contrib/googletest)

add_executable(lobster_tests tests/store_test.cpp)
target_link_libraries(lobster_tests PRIVATE lobster_core GTest::gtest_main)
target_include_directories(lobster_core PUBLIC src)
