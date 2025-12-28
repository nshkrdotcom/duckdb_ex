# Installation & Setup

DuckdbEx runs the DuckDB CLI via `erlexec`. Install the CLI first, then add the
Hex dependency.

## DuckDB CLI

You can install DuckDB in two ways:

1. Run the built-in installer to download the CLI into your project’s
   `priv/duckdb/duckdb` (or `priv/duckdb/duckdb.exe` on Windows). This path is
   ignored by git:

```bash
mix duckdb_ex.install
```

Optional version pinning:

```bash
mix duckdb_ex.install --version 1.4.3
```

2. Or install DuckDB from the official releases or your package manager, then
   ensure the `duckdb` binary is on your PATH.

In both cases you can set `DUCKDB_PATH` to the full path of the binary.

Example (shell):

```bash
export DUCKDB_PATH="/usr/local/bin/duckdb"
```

If you need to run the CLI as root (some container environments), set:

```bash
export DUCKDB_EX_EXEC_AS_ROOT=1
```

## Add Dependency

```elixir
def deps do
  [
    {:duckdb_ex, "~> 0.2.0"}
  ]
end
```

## Verify

```elixir
{:ok, _conn} = DuckdbEx.execute("SELECT 1")
{:ok, rows} = DuckdbEx.fetchall()
# rows == [{1}]
```
