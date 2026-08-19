# min version for cmake to run 
cmake_minimum_required(VERSION 3.23)

# project name for this (internally this does many things)
project(lobster)

# to name and specify the executable
add_executable(lobster)

# to describe which things to build here 
target_sources(lobster
  PRIVATE
    src/main.cpp
)
