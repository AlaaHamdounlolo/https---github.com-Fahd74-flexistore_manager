################################################################################
# FlexiStore Manager — Root CMakeLists.txt
# Outputs: flexistore.dll (shared library consumed by Flutter via dart:ffi)
# Standard: C++17
# Dependencies: MySQL Connector/C++ (libmysqlcppconn)
################################################################################
cmake_minimum_required(VERSION 3.20)
if(POLICY CMP0144)
    cmake_policy(SET CMP0144 NEW)
endif()
project(flexistore VERSION 1.0.0 LANGUAGES CXX)

# ── C++17 Standard ────────────────────────────────────────────────────────────
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ── Append our custom cmake/ directory so FindMySQL.cmake is discoverable ─────
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# ── Locate MySQL Connector/C++ ────────────────────────────────────────────────
# Note: MySQL package name changed from "MySQL" to "MySQLConnector" in newer FindMySQL.cmake
# Try both package names to be robust
find_package(MySQL QUIET)
if(NOT MySQL_FOUND)
    find_package(MySQLConnector REQUIRED)
endif()

# ── Collect ALL source files from every team module ───────────────────────────
file(GLOB_RECURSE CORE_SOURCES        "src/core/*.cpp")
file(GLOB_RECURSE AUTH_SOURCES        "src/auth/*.cpp")
file(GLOB_RECURSE AUDIT_SOURCES       "src/audit/*.cpp")
file(GLOB_RECURSE INVENTORY_SOURCES   "src/inventory/*.cpp")
file(GLOB_RECURSE CLIENTS_SOURCES     "src/clients/*.cpp")
file(GLOB_RECURSE POS_SOURCES         "src/pos/*.cpp")
file(GLOB_RECURSE INSTALLMENT_SOURCES "src/installments/*.cpp")
file(GLOB_RECURSE RETURNS_SOURCES     "src/returns/*.cpp")
file(GLOB_RECURSE DASHBOARD_SOURCES   "src/dashboard/*.cpp")

# ── Define the shared library target ──────────────────────────────────────────
add_library(flexistore SHARED
    ${CORE_SOURCES}
    ${AUTH_SOURCES}
    ${AUDIT_SOURCES}
    ${INVENTORY_SOURCES}
    ${CLIENTS_SOURCES}
    ${POS_SOURCES}
    ${INSTALLMENT_SOURCES}
    ${RETURNS_SOURCES}
    ${DASHBOARD_SOURCES}
)

# ── Export macro so every team uses the same DLL‐export attribute ─────────────
target_compile_definitions(flexistore PRIVATE FLEXISTORE_EXPORTS)

# ── Include paths ─────────────────────────────────────────────────────────────
target_include_directories(flexistore
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src          # allows includes like "core/db_config.h"
        ${MYSQL_INCLUDE_DIRS}            # MySQL Connector headers
        ${MYSQL_INCLUDE_DIRS}/jdbc       # For MySQL Connector 9.x JDBC compatibility
)

# ── Link MySQL Connector/C++ ─────────────────────────────────────────────────
target_link_libraries(flexistore PRIVATE ${MYSQL_LIBRARIES})

# ── Windows-specific: suppress min/max macros that break <algorithm> ──────────
if(WIN32)
    target_compile_definitions(flexistore PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN _ITERATOR_DEBUG_LEVEL=0)
    # Enforce Release CRT (/MD) to avoid bad_alloc and ABI mismatches with MySQL Connector
    set_property(TARGET flexistore PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreadedDLL")

    # CRITICAL: Flutter injects /MDd into global CMake flags for debug builds.
    # We MUST scrub /MDd and replace it with /MD so MSVC doesn't pick /MDd over the property.
    string(REPLACE "/MDd" "/MD" CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}")
    string(REPLACE "/MDd" "/MD" CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG}")
    string(REPLACE "/MDd" "/MD" CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_CXX_FLAGS_RELWITHDEBINFO}")
    string(REPLACE "/MDd" "/MD" CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO}")
endif()

# ── Output the DLL directly into a predictable location ───────────────────────
set_target_properties(flexistore PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
    PREFIX ""                       # produce "flexistore.dll" not "libflexistore.dll"
)

message(STATUS "──────────────────────────────────────────────")
message(STATUS "FlexiStore Manager — Build Configuration")
message(STATUS "  C++ Standard  : C++${CMAKE_CXX_STANDARD}")
message(STATUS "  MySQL Include : ${MYSQL_INCLUDE_DIRS}")
message(STATUS "  MySQL Lib     : ${MYSQL_LIBRARIES}")
message(STATUS "  Output Dir    : ${CMAKE_BINARY_DIR}/bin")
message(STATUS "──────────────────────────────────────────────")
