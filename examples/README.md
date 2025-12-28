# DuckDB Elixir Examples

This directory contains practical examples demonstrating how to use DuckDB with Elixir.

## Running Examples

All examples can be run using `mix run`:

```bash
mix run examples/01_basic_queries.exs
```

Ensure the DuckDB CLI is available first:

```bash
mix duckdb_ex.install
```

## Available Examples

### 1. Basic Queries (`01_basic_queries.exs`)
Introduction to DuckDB with simple queries:
- Simple SELECT statements
- Math operations
- String functions
- Date/time operations
- Aggregations

```bash
mix run examples/01_basic_queries.exs
```

### 2. Tables and Data Management (`02_tables_and_data.exs`)
Working with tables and data:
- Creating tables
- Inserting data
- Querying and filtering
- Aggregating by groups
- Updating and deleting data
- Dropping tables

```bash
mix run examples/02_tables_and_data.exs
```

### 3. Transactions (`03_transactions.exs`)
Transaction management and ACID properties:
- Successful transactions
- Automatic rollback on errors
- Exception handling
- Manual transaction control (BEGIN/COMMIT/ROLLBACK)
- The `transaction/2` helper function

```bash
mix run examples/03_transactions.exs
```

### 4. Relations API (`04_relations_api.exs`)
Lazy query building with the Relations API:
- Creating relations from tables
- Filtering data
- Projecting columns
- Ordering results
- Aggregations
- Chaining operations
- Using custom SQL

```bash
mix run examples/04_relations_api.exs
```

### 5. File Formats (`05_csv_parquet_json.exs`)
Reading and writing different file formats:
- Reading CSV files with `read_csv/2`
- Exporting to Parquet format
- Reading Parquet files
- Exporting to JSON via SQL `COPY`
- Reading JSON files
- Combining multiple file formats in queries

```bash
mix run examples/05_csv_parquet_json.exs
```

### 6. Analytics & Window Functions (`06_analytics_window_functions.exs`)
Advanced analytics with window functions:
- ROW_NUMBER() and RANK()
- Running totals
- Moving averages
- LAG and LEAD functions
- Percentiles and quartiles
- Partitioning by categories

```bash
mix run examples/06_analytics_window_functions.exs
```

### 7. Persistent Databases (`07_persistent_database.exs`)
Working with file-based databases:
- Creating persistent databases
- Reconnecting to existing databases
- Read-only connections
- Checkpoints
- Database file management

```bash
mix run examples/07_persistent_database.exs
```

## Running All Examples

You can run all examples sequentially:

```bash
examples/run_all.sh
```

## Quick Tips

### In-Memory vs Persistent
```elixir
# In-memory (temporary, fast)
{:ok, conn} = Connection.connect(:memory)

# Persistent (saved to disk)
{:ok, conn} = Connection.connect("/path/to/database.duckdb")

# Read-only
{:ok, conn} = Connection.connect("/path/to/database.duckdb", read_only: true)
```

### Query Patterns
```elixir
# Execute and get result
{:ok, result} = Connection.execute_result(conn, "SELECT * FROM users")

# Fetch all rows (tuples)
{:ok, rows} = Connection.fetch_all(conn, "SELECT * FROM users")

# Fetch one row
{:ok, row} = Connection.fetch_one(conn, "SELECT * FROM users WHERE id = 1")

# Using relations (lazy evaluation)
result = Connection.table(conn, "users")
  |> Relation.filter("age > 18")
  |> Relation.order("name ASC")
  |> Relation.fetch_all()
```

### Transactions
```elixir
# Automatic transaction management (recommended)
{:ok, result} = Connection.transaction(conn, fn conn ->
  {:ok, _} = Connection.execute(conn, "UPDATE accounts SET balance = balance - 100 WHERE id = 1")
  {:ok, _} = Connection.execute(conn, "UPDATE accounts SET balance = balance + 100 WHERE id = 2")
  :success
end)

# Manual control
{:ok, _} = Connection.begin(conn)
{:ok, _} = Connection.execute(conn, "INSERT INTO users VALUES (1, 'Alice')")
{:ok, _} = Connection.commit(conn)
```

## Performance Tips

1. **Use parameter binding** for repeated queries
2. **Use transactions** for bulk inserts
3. **Use Parquet** for analytical workloads (much faster than CSV)
4. **Use window functions** instead of multiple passes over data
5. **Partition data** when working with large datasets

## More Information

- [DuckDB Documentation](https://duckdb.org/docs/)
- [DuckDB SQL Reference](https://duckdb.org/docs/sql/introduction)
- [Project README](../README.md)
