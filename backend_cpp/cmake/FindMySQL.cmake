################################################################################
# FindMySQL.cmake
# Locates MySQL Connector/C++ (headers + library) on Windows.
#
# Output variables:
#   MYSQL_FOUND        — TRUE if both headers and library are found.
#   MYSQL_INCLUDE_DIRS — Path to the connector include directory.
#   MYSQL_LIBRARIES    — Full path to the connector library file.
#
# Users can hint the location via:
#   -DMYSQL_ROOT=<path>          (CMake variable)
#   Environment: MYSQL_DIR       (environment variable)
################################################################################

# ── Search for the main header ────────────────────────────────────────────────
find_path(MYSQL_INCLUDE_DIRS
    NAMES
        mysql/jdbc.h                  # MySQL Connector/C++ (JDBC-style API)
        cppconn/driver.h              # Alternative header layout
    HINTS
        ${MYSQL_ROOT}
        $ENV{MYSQL_DIR}
        $ENV{MYSQL_ROOT}
    PATHS
        "C:/Program Files/MySQL/MySQL Connector C++ 8.0"
        "C:/Program Files/MySQL/MySQL Connector C++ 9.0"
        "C:/Program Files/MySQL/MySQL Connector C++ 9.1"
        "C:/Program Files/MySQL/MySQL Connector C++ 9.2"
        "C:/Program Files/MySQL/MySQL Connector C++ 9.7"
        "C:/Program Files (x86)/MySQL/MySQL Connector C++ 8.0"
        "C:/mysql-connector-c++"
    PATH_SUFFIXES
        include
        include/jdbc
)

# ── Search for the library file ───────────────────────────────────────────────
find_library(MYSQL_LIBRARIES
    NAMES
        mysqlcppconn                  # Release build
        mysqlcppconn-static           # Static variant
        mysqlcppconn8                 # Connector 8.x / X DevAPI variant
        mysqlcppconn9
    HINTS
        ${MYSQL_ROOT}
        $ENV{MYSQL_DIR}
        $ENV{MYSQL_ROOT}
    PATHS
        "C:/Program Files/MySQL/MySQL Connector C++ 8.0"
        "C:/Program Files/MySQL/MySQL Connector C++ 9.0"
        "C:/Program Files/MySQL/MySQL Connector C++ 9.1"
        "C:/Program Files/MySQL/MySQL Connector C++ 9.2"
        "C:/Program Files/MySQL/MySQL Connector C++ 9.7"
        "C:/Program Files (x86)/MySQL/MySQL Connector C++ 8.0"
        "C:/mysql-connector-c++"
    PATH_SUFFIXES
        lib
        lib64
        lib64/vs14
        lib/vs14
        lib/opt
)

# ── Standard CMake find-package handling ──────────────────────────────────────
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(MySQL
    REQUIRED_VARS
        MYSQL_INCLUDE_DIRS
        MYSQL_LIBRARIES
    FAIL_MESSAGE
        "Could not find MySQL Connector/C++. Set -DMYSQL_ROOT=<path> or the MYSQL_DIR environment variable."
)

# ── Mark as advanced so they don't clutter the CMake GUI ──────────────────────
mark_as_advanced(MYSQL_INCLUDE_DIRS MYSQL_LIBRARIES)
