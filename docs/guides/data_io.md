# Data Import & Export

DuckdbEx exposes read functions on `DuckdbEx` and `DuckdbEx.Connection` and
export functions on `DuckdbEx.Relation`.

## Read CSV

```elixir
rel = DuckdbEx.read_csv("data.csv", header: true, sep: ",")
{:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
```

## Read JSON

```elixir
rel = DuckdbEx.read_json("data.json")
```

## Read Parquet

```elixir
rel = DuckdbEx.read_parquet("data.parquet")
```

## Export CSV

```elixir
rel = DuckdbEx.Connection.sql(conn, "SELECT * FROM users")
DuckdbEx.Relation.to_csv(rel, "users.csv", header: true)
```

## Export Parquet

```elixir
DuckdbEx.Relation.to_parquet(rel, "users.parquet", compression: "zstd")
```

### Partitioned Output

```elixir
DuckdbEx.Relation.to_parquet(rel, "out_dir",
  partition_by: ["country"],
  filename_pattern: "chunk_{i}"
)
```

## Notes

- Options are passed to DuckDB table functions and `COPY` where possible.
- Some advanced options (DataFrame/Arrow integration) are not available in the
  CLI backend; use SQL or export files as a workaround.
