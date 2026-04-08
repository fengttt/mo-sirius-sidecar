# mo-duckdb-sidecar

DuckDB-based sidecar for MatrixOne's GPU offload. Queries annotated with
`/*+ GPU */` in MO are rewritten and forwarded to this sidecar, which reads
TAE storage objects directly and returns results via HTTP.

## Extensions

| Extension | Source | Description |
|-----------|--------|-------------|
| **tae-scanner** | [duckdb-tae-scanner](https://github.com/matrixorigin/duckdb-tae-scanner) | Reads MatrixOne TAE storage objects as DuckDB table functions |
| **httpserver** | [duckdb-httpserver](https://github.com/matrixorigin/duckdb-httpserver) | ClickHouse-compatible HTTP server for accepting SQL queries |
| **sirius** | [sirius](https://github.com/matrixorigin/sirius) | GPU-accelerated SQL execution via cuCascade/cuDF |

Both are statically linked into the DuckDB binary — no manual `LOAD` needed.

## Prerequisites

CMake ≥ 3.15, Ninja, Clang (recommended) or GCC ≥ 11, plus lz4 and OpenSSL dev
libraries.

**Debian / Ubuntu:**
```bash
sudo apt install clang cmake ninja-build liblz4-dev libssl-dev git
```

**Fedora / RHEL / Rocky:**
```bash
sudo dnf install clang cmake ninja-build lz4-devel openssl-devel git
```

**Arch Linux:**
```bash
sudo pacman -S clang cmake ninja lz4 openssl git
```

## Build

```bash
git clone --recurse-submodules https://github.com/matrixorigin/mo-duckdb-sidecar.git
cd mo-duckdb-sidecar

# Configure (first time only)
cmake -S duckdb -B build/release -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DDUCKDB_EXTENSION_CONFIGS="$(pwd)/extension_config.cmake"

# Build
ninja -C build/release
```

Artifacts:
- `build/release/duckdb` — DuckDB shell with both extensions linked
- `build/release/extension/tae_scanner/tae_scanner.duckdb_extension` — loadable
- `build/release/extension/httpserver/httpserver.duckdb_extension` — loadable

### GPU build (requires CUDA)

```bash
cmake -S duckdb -B build/release-gpu -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DDUCKDB_EXTENSION_CONFIGS="$(pwd)/extension_config_gpu.cmake"

ninja -C build/release-gpu
```

This adds the Sirius GPU execution engine on top of tae_scanner + httpserver.

## Deploy

### Quick start

```bash
DUCKDB_HTTPSERVER_PORT=9876 ./build/release/duckdb -unsigned
```

The HTTP server auto-starts on the specified port. No `-cmd` flags needed.

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DUCKDB_HTTPSERVER_PORT` | *(none)* | Set to auto-start HTTP server on this port |
| `DUCKDB_HTTPSERVER_HOST` | `0.0.0.0` | Listen address |
| `DUCKDB_HTTPSERVER_AUTH` | *(empty)* | Auth token (X-API-Key or Basic auth) |

### Manual start (interactive)

```bash
./build/release/duckdb -unsigned \
  -cmd "SELECT httpserve_start('0.0.0.0', 9876, '')"
```

### Verify

```bash
curl 'http://localhost:9876/?default_format=JSONCompact&query=SELECT+42'
```

## MatrixOne integration

1. Start the sidecar on port 9876 (see Deploy above)
2. Start MO with `-debug-http :8888`
3. Configure the sidecar URL in MO:
   ```toml
   # etc/launch/cn.toml
   [cn.frontend]
   gpuSidecarUrl = "http://localhost:9876"
   ```
   Or per-session: `SET gpu_sidecar_url = 'http://localhost:9876';`
4. Run queries with the GPU hint (note: `--comments` flag needed for mariadb client):
   ```sql
   /*+ GPU */ SELECT count(*) FROM tpch.lineitem WHERE l_shipdate < '1998-09-01';
   ```

## How it works

```
Client                  MatrixOne                Sidecar (DuckDB)
  │                         │                         │
  │  /*+ GPU */ SELECT ...  │                         │
  │────────────────────────>│                         │
  │                         │  GET /debug/tae/manifest│
  │                         │  (internal, for schema) │
  │                         │                         │
  │                         │  Rewrite: table refs →  │
  │                         │  tae_scan(manifest_url) │
  │                         │                         │
  │                         │  POST rewritten SQL     │
  │                         │────────────────────────>│
  │                         │                         │ tae_scan reads
  │                         │                         │ TAE objects from
  │                         │                         │ shared storage
  │                         │  JSONCompact response   │
  │                         │<────────────────────────│
  │  MySQL result set       │                         │
  │<────────────────────────│                         │
```

## Architecture

```
mo-duckdb-sidecar/
├── duckdb/                  ← DuckDB v1.5.1 (submodule)
├── extension-ci-tools/      ← DuckDB build helpers (submodule)
├── tae-scanner/             ← TAE storage reader extension (submodule)
│   ├── src/                 ← Scanner, column fill, filter pushdown, object reader
│   └── include/             ← Headers
├── httpserver/              ← HTTP query server extension (submodule)
│   └── src/                 ← Server, JSON/CSV/XML serializers
├── sirius/                  ← GPU SQL execution engine (submodule)
│   └── src/                 ← GPU physical operators, cuCascade integration
├── extension_config.cmake   ← Master config loading tae-scanner + httpserver
├── Makefile                 ← Convenience wrapper (calls cmake + ninja)
├── DESIGN.md                ← Full architecture document
└── README.md
```
