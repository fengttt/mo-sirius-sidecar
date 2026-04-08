# Master extension config for mo-duckdb-sidecar.
# Loads tae_scanner and httpserver extensions into a single DuckDB build.

duckdb_extension_load(tae_scanner
    SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR}/tae-scanner
    INCLUDE_DIR ${CMAKE_CURRENT_LIST_DIR}/tae-scanner/include
    LOAD_TESTS
)

duckdb_extension_load(httpserver
    SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR}/httpserver
    LOAD_TESTS
)
