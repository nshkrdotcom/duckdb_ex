# Type System & Expressions

DuckdbEx currently exposes SQL-first APIs. Type constructors and expression
objects are not yet implemented as Elixir data structures.

## Recommended Usage Today

Use SQL type strings and casts:

```elixir
DuckdbEx.execute("SELECT 42::INTEGER")
DuckdbEx.execute("SELECT CAST('2024-01-01' AS DATE)")
```

## Planned API

Future work may add `DuckdbEx.Type` and expression helpers to mirror the Python
API (`duckdb.typing`, `duckdb.Expression`). Until then, prefer SQL strings for
types and expressions.
