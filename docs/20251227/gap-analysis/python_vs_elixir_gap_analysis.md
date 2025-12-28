# DuckDB Python vs DuckdbEx Gap Analysis (2025-12-27)

Date: 2025-12-27

Scope:
- Python reference: ./duckdb-python at HEAD (2025-12-25)
- Elixir port: current workspace (duckdb_ex)

## Executive summary

- DuckdbEx covers connections, parameter binding, module-level defaults, data readers/writers, and a growing Relation API (joins, set ops, mutations, export) via SQL string rewriting.
- Large areas of the Python API remain missing: type system, expression/value/statement APIs, Arrow/DataFrame conversions, UDFs, extensions/filesystems, and most experimental integrations.
- The current Elixir implementation uses the DuckDB CLI in JSON mode, which constrains features like prepared statements, UDFs, Arrow zero-copy, and query progress.

## Current DuckdbEx implementation snapshot

### Modules and capabilities
- DuckdbEx
  - connect/2, execute/3, execute_result/3, executemany/3, close/1
  - default_connection/0, set_default_connection/1
  - fetchall/fetchone/fetchmany, description/rowcount
  - sql/query/table/view/values, read_csv/read_json/read_parquet
  - cursor/0, duplicate/0, extract_statements/1
- DuckdbEx.Connection
  - connect/2 (supports :memory and file paths; read_only option passed to CLI)
  - execute/3 with parameter binding; execute_result/3
  - executemany/3, extract_statements/2
  - description/1, rowcount/1
  - sql/3, query/4, table/2, view/2, values/2
  - read_csv/read_json/read_parquet
  - begin/commit/rollback/checkpoint, transaction/2, cursor/1, duplicate/1, close/1
- DuckdbEx.Relation
  - new/4
  - project/filter/limit/order/sort/distinct/unique
  - aggregate/2/3 and convenience helpers (count/sum/avg/min/max)
  - join/4, cross/2, union/2, intersect/2, except_/2
  - execute/1, fetch_all/1, fetch_one/1, fetch_many/2
  - to_csv/3, to_parquet/3
  - create/2, create_view/3, insert_into/2, insert/2, update/3
- DuckdbEx.Result
  - fetch_all/1, fetch_one/1, fetch_many/2
  - row_count/1
  - columns/1
  - to_tuples/1 (ordered tuples)
- DuckdbEx.Exceptions
  - Full exception hierarchy and from_error_string/1 mapping
- DuckdbEx.Port
  - Manages DuckDB CLI with erlexec, JSON-mode parsing

## Gap summary by category

### Core connection and module-level API
- Default connection holder and module-level wrappers exist for core operations (execute, fetch, sql/query, read_*).
- Cursor/duplicate implemented as lightweight wrappers.
- executemany and extract_statements implemented.
- Parameter binding implemented for `?`, `$n`, and `:name` placeholders.
- DB-API metadata helpers (description/rowcount) exposed at connection/module level.
- Still missing: `interrupt`, `query_progress`, `get_table_names`, DB-API constants/type objects.

### Relation API gaps
- table/view/values/query relations are implemented; `table_function` and `from_query` are still missing.
- to_view/to_table/to_csv/to_parquet and relation mutations (create/create_view/insert/insert_into/update) are implemented.
- Relation metadata (columns/types/dtypes/description/shape/len) still missing.
- Missing large sets of aggregates, window functions, and utility operations.
- No SQL generation helpers (to_sql, explain).
- No expression API for programmatic query construction.

### Result formats and conversions
- No fetchdf, fetch_arrow_table, fetch_record_batch, fetch_df_chunk, or numpy/polars/torch/tf outputs.
- Result tuples preserve column order via ordered JSON parsing.
- Row count for DML/DDL is not exposed; only row length is returned.

### Type system and expression/value APIs
- No DuckDB type constructors (list_type, struct_type, map_type, union_type, etc.).
- No DuckDBPyType equivalent or constants.
- No Expression, Value, or Statement APIs.
- No StatementType or ExpectedResultType enums.

### Data sources and integrations
- read_csv/read_json/read_parquet implemented via table functions with option mapping.
- No from_df/from_arrow/from_polars data ingestion.
- No register/unregister/append API.
- No filesystem registration APIs.
- No extension install/load helpers.

### Experimental interfaces
- No Spark experimental interface (DataFrame API, printSchema, dtypes, type system).
- No Polars predicate pushdown or expression translation.
- No Arrow dataset pushdown helpers.

### DB-API 2.0 compliance
- Missing apilevel, threadsafety, paramstyle constants.
- Cursor wrapper exists, but no full DB-API interface.

## New gaps introduced by duckdb-python changes since 2025-10-16

- Relation.to_parquet options (filename_pattern, file_size_bytes) are implemented in DuckdbEx.
- Spark experimental additions (types, dtypes, printSchema, DataFrameReader.load) have no equivalent in DuckdbEx.
- Spark numeric functions now return NaN (not NULL) for out-of-range asin/acos; DuckdbEx has no Spark or function wrappers.
- Polars expression parsing treats string nodes as constants; DuckdbEx has no Polars integration.
- unregister now quotes view names to prevent injection; DuckdbEx does not implement unregister/register at all.
- Schema-qualified inserts are supported in Python; DuckdbEx implements insert for table relations (including qualified names).
- Pandas date/time conversion behavior and column order tests have no direct equivalents.

## Architecture-driven gaps and constraints

- DuckdbEx uses the DuckDB CLI in JSON mode, not the in-process C++ API.
  - No prepared statements or statement objects.
  - UDF registration is not feasible with the CLI.
  - No query progress or interrupt API without process signaling.
  - JSON results lose detailed type metadata and can be expensive for large datasets.
  - Arrow zero-copy and DataFrame conversions are not available.

## Compatibility matrix (high level)

| Area | Python API | DuckdbEx status | Notes |
| --- | --- | --- | --- |
| Connection basics | Full | Partial | connect/execute/close with params, default connection, executemany |
| Transactions | Full | Partial | begin/commit/rollback/checkpoint implemented |
| Relation core ops | Full | Partial | core ops, joins, set ops, mutations, export |
| Relation advanced ops | Full | Missing | window functions, many aggregates, metadata |
| Result conversions | Full | Missing | no pandas/arrow/polars/numpy outputs |
| Type system | Full | Missing | no DuckDBPyType or constructors |
| Expression/Value/Statement APIs | Full | Missing | not implemented |
| Data source readers | Full | Partial | read_csv/read_parquet/read_json implemented |
| Extensions/filesystems | Full | Missing | no install/load/register |
| Experimental Spark/Polars | Partial | Missing | no experimental modules |

## Notes for planning

- The CLI-based architecture is a core divergence. If full Python parity is a hard requirement, a NIF or embedded library approach will be needed for UDFs, prepared statements, Arrow integration, and metadata access.
- If the CLI approach remains, document a scoped compatibility target and prioritize features that are practical with SQL-only execution (readers, exporters, relation ops).
