# GPU build config: tae_scanner + httpserver + sirius (requires CUDA).
# Usage:
#   cmake -S duckdb -B build/release-gpu -G Ninja \
#     -DCMAKE_BUILD_TYPE=Release \
#     -DDUCKDB_EXTENSION_CONFIGS=<path>/extension_config_gpu.cmake

include(${CMAKE_CURRENT_LIST_DIR}/extension_config.cmake)

duckdb_extension_load(sirius
    SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR}/sirius
    LOAD_TESTS
    EXTENSION_VERSION dev
)
