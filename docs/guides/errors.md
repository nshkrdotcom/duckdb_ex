# Error Handling

DuckdbEx maps DuckDB error strings into structured exceptions. Most functions
return `{:error, exception}` tuples.

```elixir
case DuckdbEx.execute("SELECT * FROM missing_table") do
  {:ok, _} -> :ok
  {:error, exception} -> IO.inspect(exception)
end
```

Common exception types:

- `DuckdbEx.Exceptions.CatalogException`
- `DuckdbEx.Exceptions.ParserException`
- `DuckdbEx.Exceptions.InvalidInputException`
- `DuckdbEx.Exceptions.ConstraintException`

When using the CLI backend, error messages are emitted on stderr and converted
to the closest matching exception type.
