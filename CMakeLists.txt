cmake_minimum_required(VERSION 3.23)

# project name for this (internally this does many things)
project(lobster LANGUAGES CXX)

set (CMAKE_CXX_STANDARD 20)
set (CMAKE_CXX_STANDARD_REQUIRED ON)
set (CMAKE_CXX_EXTENSIONS OFF)

# to name and specify the executable
add_executable(lobster)

# to describe which things to build here 
target_sources(lobster
  PRIVATE
    src/main.cpp
)

target_compile_options(lobster PRIVATE -Wall -Wextra)
