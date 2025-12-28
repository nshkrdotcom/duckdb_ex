# Configuration

DuckdbEx is CLI-based. Configuration is primarily environment variables and SQL
settings.

## Environment Variables

- `DUCKDB_PATH`: path to the DuckDB CLI binary.
- `DUCKDB_EX_EXEC_AS_ROOT`: set to `1` or `true` to run the CLI as root.
- `DUCKDB_VERSION`: optional version for `mix duckdb_ex.install`.

Resolution order:

1. `config :duckdb_ex, :duckdb_path`
2. `DUCKDB_PATH`
3. `priv/duckdb/duckdb` (installed CLI in the project when running via Mix)
4. `duckdb` in PATH
5. `/usr/local/bin/duckdb`

## Application Config

You can pin the CLI path in config (takes precedence over `DUCKDB_PATH`):

```elixir
config :duckdb_ex, :duckdb_path, "/opt/duckdb/duckdb"
```

## Connection Options

When connecting:

```elixir
{:ok, conn} = DuckdbEx.Connection.connect("/path/to/db.duckdb", read_only: true)
```

Supported options:

- `:read_only` - open the database in read-only mode.

## SQL Configuration

Most runtime configuration is done through SQL:

```elixir
DuckdbEx.execute("SET threads=4")
DuckdbEx.execute("SET memory_limit='2GB'")
```

## Extensions

The CLI supports extensions via SQL:

```elixir
DuckdbEx.execute("INSTALL httpfs")
DuckdbEx.execute("LOAD httpfs")
```

There are no first-class Elixir wrappers yet; use SQL commands directly.
