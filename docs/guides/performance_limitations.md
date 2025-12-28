# Performance & Limitations

DuckdbEx uses the DuckDB CLI process with JSON output. This is portable and
simple, but has trade-offs.

## Performance

- Query execution time is dominated by DuckDB itself.
- JSON parsing adds overhead but is acceptable for OLAP workloads.
- Use set-based SQL operations and the Relation API to let DuckDB optimize.

## Limitations (CLI Backend)

- No zero-copy Arrow, DataFrame, or Polars integration.
- No native UDF registration.
- Cursor/duplicate are lightweight wrappers and do not open new OS processes.
- File-based databases may have external locking constraints.

## Recommended Workarounds

- Export to Parquet/CSV and load with Explorer, Arrow, or Pandas.
- Use SQL `INSTALL`/`LOAD` for extensions.
