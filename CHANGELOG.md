# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-12-27

### Added
- Default connection holder and expanded module-level API helpers (execute_result, executemany, fetch*, read_*, cursor/duplicate, extract_statements).
- Parameter binding for `?`, `$n`, and `:name` placeholders.
- Relation mutations: create/to_table, create_view/to_view, insert, insert_into, update.
- Relation export via `COPY` for CSV/Parquet including `filename_pattern` and `file_size_bytes` options.
- Values relation parity for single-row lists and multi-row tuple inputs.
- Guides under `docs/guides/` plus `examples/run_all.sh` to run all examples.
- `mix duckdb_ex.install` for installing the DuckDB CLI into the project `priv/duckdb/duckdb` with path auto-resolution.

### Changed
- Relation limit now supports offsets; sort and unique helpers added.
- Result rows are tuples with stable column order via ordered JSON parsing.
- README and guides updated to reflect CLI limitations and current API surface.

### Fixed
- CLI error normalization and JSON parsing robustness for multi-line outputs.

## [0.1.1] - 2025-10-16

### Added
- Comprehensive documentation with 8 runnable examples in examples/ directory
  - `00_quickstart.exs` - Quick start guide
  - `01_basic_queries.exs` - Basic query examples
  - `02_tables_and_data.exs` - Table operations
  - `03_transactions.exs` - Transaction management
  - `04_relations_api.exs` - Relation API demonstration
  - `05_csv_parquet_json.exs` - File format support
  - `06_analytics_window_functions.exs` - Advanced analytics
  - `07_persistent_database.exs` - Persistent database usage
- DuckdbEx.Connection module with transaction support (begin, commit, rollback, transaction helper)
- Transaction test suite with 265 tests

### Changed
- Enhanced README with extensive examples and usage documentation
- Improved DuckdbEx.Port module implementation

## [0.1.0] - 2025-10-16

### Added
- Initial release
