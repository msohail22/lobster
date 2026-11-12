cmake_minimum_required(VERSION 3.23)

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

add_executable(lobster src/main.cpp)

target_compile_options(lobster PRIVATE -Wall -Wextra -Wpedantic)

# Tests are opt-in so a plain build stays fast.
option(ENABLE_TESTS "Build the test suite" ON)

if(ENABLE_TESTS)
    enable_testing()
    add_test(NAME smoke COMMAND lobster)
endif()
