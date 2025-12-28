# Migration from Python

DuckdbEx mirrors the Python API, but there are a few differences.

## Result Shape

Python returns rows as tuples; DuckdbEx also returns tuples. If you previously
used dict-like access in Elixir, update code to use tuple patterns:

```elixir
{:ok, rows} = DuckdbEx.fetchall()
Enum.each(rows, fn {id, name} -> IO.puts("#{id}: #{name}") end)
```

## Default Connection

Python module-level helpers use a default connection. DuckdbEx follows this
pattern:

```elixir
DuckdbEx.execute("SELECT 1")
DuckdbEx.fetchall()
```

## Missing APIs

Some Python-only conveniences are not available in the CLI backend (Arrow,
DataFrame, UDFs). Use file export or SQL equivalents.
