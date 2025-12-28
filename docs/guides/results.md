# Result Formats

DuckdbEx returns rows as tuples in column order.

## Connection Fetching

```elixir
{:ok, rows} = DuckdbEx.fetchall()
# rows == [{1, "Alice"}, {2, "Bob"}]
```

## Result Helpers

```elixir
{:ok, result} = DuckdbEx.Connection.execute_result(conn, "SELECT 1 AS a")
rows = DuckdbEx.Result.fetch_all(result)
cols = DuckdbEx.Result.columns(result)
```

## Metadata

```elixir
DuckdbEx.Connection.execute(conn, "SELECT 42 AS answer")
{:ok, description} = DuckdbEx.Connection.description(conn)
```

## DataFrame / Arrow / Polars

The CLI backend does not provide zero-copy Arrow, DataFrame, or Polars
conversions. Use file export (CSV/Parquet) or SQL to materialize data.
