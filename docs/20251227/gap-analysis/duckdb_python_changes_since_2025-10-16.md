# DuckDB-Python Additions Since 2025-10-16

Date: 2025-12-27

Source: ./duckdb-python
Baseline commit: bbd4389 (2025-10-16)
Head commit: 3f1f615 (2025-12-25)

## Summary of additions and behavior changes

### Relation and connection API
- Added to_parquet options for file splitting and naming:
  - New options: filename_pattern, file_size_bytes
  - Implemented in C++ layer and exposed in Python stubs and initialization
  - Files: src/duckdb_py/pyrelation.cpp, src/duckdb_py/include/duckdb_python/pyrelation.hpp, src/duckdb_py/pyrelation/initialize.cpp, _duckdb-stubs/__init__.pyi
- unregister now quotes view names before executing DROP VIEW, preventing injection and handling quoted identifiers correctly
  - File: src/duckdb_py/pyconnection.cpp
- InsertRelation supports schema-qualified tables (insert into schema.table)
  - Test change indicates behavior is now supported
  - File: tests/fast/test_insert.py

### Result conversion and pandas
- Pandas date/time conversions now share a single conversion path and support date_as_object without reordering columns
  - File: src/duckdb_py/pyresult.cpp, src/duckdb_py/include/duckdb_python/pyresult.hpp
- New column order test for pandas fetchdf
  - File: tests/fast/pandas/test_column_order.py

### Polars integration
- Polars expression parsing treats String and StringOwned nodes as constant expressions, preventing SQL injection through expression trees
  - File: duckdb/polars_io.py
- Added compatibility handling for Polars 1.36+ (arrow extension types) and pre-1.36 behavior
  - File: tests/fast/arrow/test_polars.py
- Added tests ensuring string nodes are always constants
  - File: tests/fast/arrow/test_polars.py

### Experimental Spark interface
- New Spark SQL type system implementation (DataType, StructType, Row, etc.)
  - File: duckdb/experimental/spark/sql/types.py
- DataFrame.dtypes property added
  - File: duckdb/experimental/spark/sql/dataframe.py
- DataFrame.printSchema implemented using treeString
  - File: duckdb/experimental/spark/sql/dataframe.py
- DataFrameReader.load now returns a DataFrame instead of raising NotImplementedError
  - File: duckdb/experimental/spark/sql/readwriter.py
- asin and acos now return NaN (not NULL) for out-of-range inputs, matching PySpark semantics
  - File: duckdb/experimental/spark/sql/functions.py
- Union type handling explicitly raises a Spark-specific error
  - File: duckdb/experimental/spark/sql/type_utils.py
- Expanded Spark test coverage
  - File: tests/fast/spark/test_spark_dataframe.py, tests/fast/spark/test_spark_functions_numeric.py

### Arrow integration
- Added tests for string_view and binary_view filter behavior in pyarrow datasets
  - File: tests/fast/arrow/test_filter_pushdown.py

### Type stubs and API signatures
- pl() overloads now distinguish eager vs lazy return types (polars.DataFrame vs polars.LazyFrame)
- connect() config typing expanded to allow bool, int, float, list
- ConstantExpression and LambdaExpression typing broadened; StarExpression signature simplified
  - File: _duckdb-stubs/__init__.pyi

### Pandas scan serialization hook
- Added a deserialize hook to PandasScanFunction (still not implemented and raises)
  - File: src/duckdb_py/pandas/scan.cpp, src/duckdb_py/include/duckdb_python/pandas/pandas_scan.hpp

## Tests added or expanded

- Default connection behavior, cursor handling, executemany, extract_statements, expected result types, rowcount/description
  - File: tests/fast/api/test_duckdb_connection.py
- to_parquet options coverage (filename_pattern, file_size_bytes, row_group_size_bytes, partitioning, append)
  - File: tests/fast/api/test_to_parquet.py
- Spark DataFrame creation and schema behavior
  - File: tests/fast/spark/test_spark_dataframe.py
- Additional Arrow/Polars and pandas tests noted above

## Build, packaging, and CI additions

- New GitHub workflows for targeted tests and automated submodule update PRs
  - Files: .github/workflows/targeted_test.yml, .github/workflows/submodule_auto_pr.yml
- Windows ARM64 wheel build support and related dependency gating
  - File: pyproject.toml, .github/workflows/packaging_wheels.yml
- Explicit extension linking and BUILD_EXTENSIONS rename
  - File: cmake/duckdb_loader.cmake, pyproject.toml, CMakeLists.txt
- Changelog link now points to duckdb-python releases; Development Status set to Production/Stable
  - File: pyproject.toml
- ADBC driver path resolution uses importlib.util and removes debug output
  - File: adbc_driver_duckdb/__init__.py

## Submodule updates

- Multiple updates to external/duckdb core submodule between 2025-10-16 and 2025-12-25
  - File: external/duckdb
