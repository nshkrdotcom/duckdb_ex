# DuckDB Elixir - Implementation Status

## Overview

DuckdbEx ports the DuckDB Python client to Elixir using the DuckDB CLI in JSON
mode via erlexec. The focus is API parity where feasible with the CLI backend.

## Update (2025-12-27)

- Added parameter binding, executemany, statement parsing, and DB-API metadata.
- Added default connection holder and cursor wrapper.
- Added Relation API core ops, joins, set ops, mutations, and export.
- Added read_csv/read_json/read_parquet with option mapping.
- Result rows are tuples with stable column order.

## Architecture

```
Elixir Application
  ↓
DuckdbEx.Connection / DuckdbEx.Relation
  ↓
DuckdbEx.Port (GenServer)
  ↓
erlexec (OS process manager)
  ↓
duckdb CLI (JSON mode)
```

## Current Status

### DuckdbEx.Port
- CLI process lifecycle, JSON parsing, ordered columns, error mapping.

### DuckdbEx.Connection
- connect/execute/execute_result/executemany
- fetch_all/fetch_one/fetch_many, description/rowcount
- sql/query/table/view/values
- read_csv/read_json/read_parquet
- transactions, cursor/duplicate, close

### DuckdbEx.Relation
- project/filter/limit (offset)/order/sort/distinct/unique
- aggregate + convenience helpers
- joins + set ops
- create/create_view/to_table/to_view
- insert/insert_into/update
- to_csv/to_parquet
- execute/fetch_all/fetch_one/fetch_many

### DuckdbEx.Result
- fetch_all/fetch_one/fetch_many
- row_count, columns, to_tuples

### DuckdbEx.Exceptions
- Full exception hierarchy + error parsing

## Remaining Gaps

- Type system (`DuckdbEx.Type`) and value/expression/statement APIs.
- Arrow/DataFrame conversions (Explorer/Nx).
- Extensions, filesystems, UDFs, query progress/interrupt.
- DB-API constants and type objects.

## Next Steps

1. Implement Type and Expression APIs.
2. Add result conversions (Explorer, Arrow) where feasible.
3. Add extension/filesystem helpers and `get_table_names`.
