cmake_minimum_required(VERSION 3.22.1)
project("local_auth_kit" C CXX)

add_library(local_auth_kit SHARED
    src/main/cpp/dn_local_auth_bridge.cpp
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_library(log-lib log)
find_library(android-lib android)

target_link_libraries(local_auth_kit
    ${log-lib}
    ${android-lib}
)
