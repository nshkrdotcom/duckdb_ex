<p align="center">
  <img src="assets/duckdb_ex.svg" alt="DuckDB Elixir Client Logo" width="200" height="200">
</p>

# DuckDB Elixir

[![CI](https://github.com/nshkrdotcom/duckdb_ex/actions/workflows/elixir.yaml/badge.svg)](https://github.com/nshkrdotcom/duckdb_ex/actions/workflows/elixir.yaml)
[![Elixir](https://img.shields.io/badge/elixir-1.18.3-purple.svg)](https://elixir-lang.org)
[![OTP](https://img.shields.io/badge/otp-27.3.3-blue.svg)](https://www.erlang.org)
[![Hex.pm](https://img.shields.io/hexpm/v/duckdb_ex.svg)](https://hex.pm/packages/duckdb_ex)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/duckdb_ex)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/nshkrdotcom/duckdb_ex/blob/main/LICENSE)

A DuckDB client for Elixir, providing a powerful Relation API for analytical queries.

> **Status**: 🚀 Core Relation API implemented and tested - Ready for evaluation

## About

DuckdbEx brings DuckDB's analytical power to Elixir with:

- **Lazy Relation API**: Composable, chainable query building inspired by Python's DuckDB API
- **CLI-based Architecture**: Uses DuckDB CLI via erlexec for maximum portability
- **Idiomatic Elixir**: Functional, pipe-friendly API with pattern matching
- **Comprehensive Testing**: TDD approach with 158 passing tests
- **Python API Alignment**: SQL and Relation behavior mirror duckdb-python where feasible with the CLI backend

## Installation

### Requirements

DuckdbEx runs the DuckDB CLI via erlexec.

- Recommended: `mix duckdb_ex.install` (installs to your project’s `priv/duckdb/duckdb`, or `priv/duckdb/duckdb.exe` on Windows)
- Or install the DuckDB CLI (`duckdb`) and ensure it is on PATH, or set `DUCKDB_PATH` to the binary.
- Optional: set `DUCKDB_EX_EXEC_AS_ROOT=1` to run the CLI as root (helpful in containers that require it).

```bash
mix duckdb_ex.install
```

```elixir
# Add to mix.exs
def deps do
  [
    {:duckdb_ex, "~> 0.2.0"}
  ]
end
```

## Quick Start

> **💡 New!** Check out the [examples/README.md](examples/README.md) guide for 8 comprehensive, runnable examples:
> ```bash
> mix run examples/00_quickstart.exs
> mix run examples/01_basic_queries.exs
> mix run examples/02_tables_and_data.exs
> # ... and more!
> ```

## Configuration

- Resolution order: `config :duckdb_ex, :duckdb_path` → `DUCKDB_PATH` → `priv/duckdb/duckdb` → `duckdb` in PATH → `/usr/local/bin/duckdb`
- `DUCKDB_EX_EXEC_AS_ROOT` - Set to `1` or `true` to run the CLI as root (useful in some containerized environments).

### Basic Connection and Queries

```elixir
# Connect to in-memory database
{:ok, conn} = DuckdbEx.Connection.connect(:memory)

# Or connect to a file
{:ok, conn} = DuckdbEx.Connection.connect("/path/to/database.duckdb")

# Execute SQL directly
{:ok, result} = DuckdbEx.Connection.execute_result(conn, "SELECT 42 as answer")

# Fetch all rows as tuples
{:ok, rows} = DuckdbEx.Connection.fetch_all(conn, "SELECT * FROM users")
# => [{1, "Alice"}, ...]

# Fetch single row
{:ok, row} = DuckdbEx.Connection.fetch_one(conn, "SELECT * FROM users LIMIT 1")
# => {1, "Alice"}

# Close connection
DuckdbEx.Connection.close(conn)
```

### Relation API - Lazy Query Building

The Relation API allows you to build complex queries through method chaining, with execution deferred until you fetch results:

```elixir
# Create a relation (no execution yet)
relation = DuckdbEx.Connection.table(conn, "orders")

# Chain operations (still no execution)
result = relation
|> DuckdbEx.Relation.filter("amount > 100")
|> DuckdbEx.Relation.project(["customer_name", "amount", "order_date"])
|> DuckdbEx.Relation.order("amount DESC")
|> DuckdbEx.Relation.limit(10)
|> DuckdbEx.Relation.fetch_all()  # Executes here

# Result: Top 10 orders over $100
{:ok, rows} = result
```

### Working with Relations

#### Creating Relations

```elixir
# From a table or view
relation = DuckdbEx.Connection.table(conn, "products")

# From SQL
relation = DuckdbEx.Connection.sql(conn, "SELECT * FROM generate_series(1, 100)")

# From range (using DuckDB's range function)
relation = DuckdbEx.Connection.sql(conn, "SELECT * FROM range(10)")

# From values
relation = DuckdbEx.Connection.values(conn, [1, "a"])
relation = DuckdbEx.Connection.values(conn, [{1, "a"}, {2, "b"}])
```

#### Filtering Data

```elixir
# Simple filter
relation
|> DuckdbEx.Relation.filter("price > 50")
|> DuckdbEx.Relation.fetch_all()

# Chain multiple filters (AND logic)
relation
|> DuckdbEx.Relation.filter("price > 50")
|> DuckdbEx.Relation.filter("category = 'Electronics'")
|> DuckdbEx.Relation.fetch_all()

# Complex conditions
relation
|> DuckdbEx.Relation.filter("price > 50 AND (category = 'Electronics' OR category = 'Computers')")
|> DuckdbEx.Relation.fetch_all()
```

#### Selecting Columns

```elixir
# Select specific columns
relation
|> DuckdbEx.Relation.project(["name", "price"])
|> DuckdbEx.Relation.fetch_all()

# Use expressions
relation
|> DuckdbEx.Relation.project([
  "name",
  "price",
  "price * 1.1 as price_with_tax",
  "upper(category) as category_upper"
])
|> DuckdbEx.Relation.fetch_all()
```

#### Sorting and Limiting

```elixir
# Order by column
relation
|> DuckdbEx.Relation.order("price DESC")
|> DuckdbEx.Relation.fetch_all()

# Multiple columns
relation
|> DuckdbEx.Relation.order("category ASC, price DESC")
|> DuckdbEx.Relation.fetch_all()

# Limit results
relation
|> DuckdbEx.Relation.limit(100)
|> DuckdbEx.Relation.fetch_all()

# Top-N query
relation
|> DuckdbEx.Relation.order("revenue DESC")
|> DuckdbEx.Relation.limit(10)
|> DuckdbEx.Relation.fetch_all()
```

### Aggregations

#### Simple Aggregations

```elixir
# Count all rows
relation
|> DuckdbEx.Relation.aggregate("count(*) as total")
|> DuckdbEx.Relation.fetch_all()
# => {:ok, [{1000}]}

# Multiple aggregations
relation
|> DuckdbEx.Relation.aggregate([
  "count(*) as count",
  "sum(amount) as total",
  "avg(amount) as average",
  "min(amount) as minimum",
  "max(amount) as maximum"
])
|> DuckdbEx.Relation.fetch_all()
```

#### GROUP BY Aggregations

```elixir
# Group by single column
DuckdbEx.Connection.table(conn, "sales")
|> DuckdbEx.Relation.aggregate(
  "sum(amount) as total_sales",
  group_by: ["region"]
)
|> DuckdbEx.Relation.fetch_all()

# Group by multiple columns
DuckdbEx.Connection.table(conn, "sales")
|> DuckdbEx.Relation.aggregate(
  ["sum(amount) as total", "count(*) as count"],
  group_by: ["region", "year"]
)
|> DuckdbEx.Relation.fetch_all()

# With filtering and ordering
DuckdbEx.Connection.table(conn, "products")
|> DuckdbEx.Relation.filter("price > 10")  # WHERE clause
|> DuckdbEx.Relation.aggregate(
  ["sum(price) as total", "count(*) as count"],
  group_by: ["category"]
)
|> DuckdbEx.Relation.filter("total > 1000")  # HAVING clause
|> DuckdbEx.Relation.order("total DESC")
|> DuckdbEx.Relation.fetch_all()
```

#### Convenience Aggregate Methods

```elixir
# Count rows
relation |> DuckdbEx.Relation.count() |> DuckdbEx.Relation.fetch_all()
# => {:ok, [{100}]}

# Sum a column
relation |> DuckdbEx.Relation.sum("amount") |> DuckdbEx.Relation.fetch_all()
# => {:ok, [{45000}]}

# Average
relation |> DuckdbEx.Relation.avg("price") |> DuckdbEx.Relation.fetch_all()
# => {:ok, [{42.5}]}

# Min/Max
relation |> DuckdbEx.Relation.min("temperature") |> DuckdbEx.Relation.fetch_all()
relation |> DuckdbEx.Relation.max("score") |> DuckdbEx.Relation.fetch_all()
```

### Complete Examples

#### E-commerce Analytics

```elixir
{:ok, conn} = DuckdbEx.Connection.connect(:memory)

# Create and populate table
DuckdbEx.Connection.execute(conn, """
  CREATE TABLE orders (
    order_id INTEGER,
    customer_name VARCHAR,
    product_category VARCHAR,
    amount DECIMAL(10,2),
    order_date DATE
  )
""")

DuckdbEx.Connection.execute(conn, """
  INSERT INTO orders VALUES
    (1, 'Alice', 'Electronics', 999.99, '2024-01-15'),
    (2, 'Bob', 'Books', 29.99, '2024-01-16'),
    (3, 'Alice', 'Electronics', 49.99, '2024-01-17'),
    (4, 'Charlie', 'Furniture', 599.99, '2024-01-18'),
    (5, 'Bob', 'Electronics', 299.99, '2024-01-19')
""")

# Analyze: Top customers by total spending in Electronics
{:ok, top_customers} =
  conn
  |> DuckdbEx.Connection.table("orders")
  |> DuckdbEx.Relation.filter("product_category = 'Electronics'")
  |> DuckdbEx.Relation.aggregate(
    ["sum(amount) as total_spent", "count(*) as order_count"],
    group_by: ["customer_name"]
  )
  |> DuckdbEx.Relation.filter("total_spent > 100")
  |> DuckdbEx.Relation.order("total_spent DESC")
  |> DuckdbEx.Relation.fetch_all()

# Result:
# [
#   {"Alice", 1049.98, 2},
#   {"Bob", 299.99, 1}
# ]
```

#### Time Series Analysis

```elixir
# Daily sales aggregation with statistical measures
{:ok, daily_stats} =
  conn
  |> DuckdbEx.Connection.table("sales")
  |> DuckdbEx.Relation.aggregate(
    [
      "date_trunc('day', timestamp) as day",
      "sum(amount) as daily_total",
      "avg(amount) as daily_avg",
      "stddev_pop(amount) as daily_stddev",
      "count(*) as transaction_count"
    ],
    group_by: ["date_trunc('day', timestamp)"]
  )
  |> DuckdbEx.Relation.order("day DESC")
  |> DuckdbEx.Relation.limit(30)
  |> DuckdbEx.Relation.fetch_all()
```

#### Data Pipeline

```elixir
defmodule DataPipeline do
  def process_sales_data(conn) do
    # Reusable base relation
    base = DuckdbEx.Connection.table(conn, "raw_sales")

    # High-value customers
    high_value = base
    |> DuckdbEx.Relation.filter("total_purchases > 1000")
    |> DuckdbEx.Relation.project(["customer_id", "email"])

    # Recent activity
    recent = base
    |> DuckdbEx.Relation.filter("order_date > '2024-01-01'")
    |> DuckdbEx.Relation.aggregate(
      "count(*) as recent_orders",
      group_by: ["customer_id"]
    )

    # Execute both queries
    {:ok, high_value_customers} = DuckdbEx.Relation.fetch_all(high_value)
    {:ok, recent_activity} = DuckdbEx.Relation.fetch_all(recent)

    {high_value_customers, recent_activity}
  end
end
```

#### Working with DuckDB Functions

```elixir
# Use DuckDB's built-in functions
conn
|> DuckdbEx.Connection.sql("SELECT * FROM range(100)")
|> DuckdbEx.Relation.filter("range % 2 = 0")  # Even numbers only
|> DuckdbEx.Relation.project(["range", "range * range as squared"])
|> DuckdbEx.Relation.fetch_all()

# Generate test data
conn
|> DuckdbEx.Connection.sql("SELECT * FROM generate_series(1, 1000) as id")
|> DuckdbEx.Relation.project([
  "id",
  "random() as random_value",
  "case when id % 2 = 0 then 'even' else 'odd' end as parity"
])
|> DuckdbEx.Relation.aggregate(
  ["avg(random_value) as avg_random", "count(*) as count"],
  group_by: ["parity"]
)
|> DuckdbEx.Relation.fetch_all()
```

## API Reference

### DuckdbEx.Connection

- `connect(database, opts \\ [])` - Open database connection
- `execute(conn, sql, params \\ [])` - Execute SQL query
- `execute_result(conn, sql, params \\ [])` - Execute and return result struct
- `executemany(conn, sql, params_list)` - Execute SQL with multiple parameter sets
- `fetch_all(conn, sql)` - Execute and fetch all rows
- `fetch_one(conn, sql)` - Execute and fetch first row
- `fetch_many(conn, sql, count)` - Execute and fetch N rows
- `close(conn)` - Close connection
- `sql(conn, sql)` - Create relation from SQL
- `table(conn, table_name)` - Create relation from table
- `view(conn, view_name)` - Create relation from view
- `values(conn, values)` - Create relation from values
- `read_csv/read_json/read_parquet` - Create relation from files

### DuckdbEx.Relation

**Transformations** (lazy, return new relation):
- `project(relation, columns)` - Select columns
- `filter(relation, condition)` - Filter rows
- `limit(relation, n, offset \\ 0)` - Limit results
- `order(relation, order_by)` - Sort results
- `sort(relation, columns)` - Sort alias (list or string)
- `unique(relation, columns)` - Distinct values for columns
- `aggregate(relation, expressions, opts \\ [])` - Aggregate data

**Convenience Aggregates**:
- `count(relation)` - Count rows
- `sum(relation, column)` - Sum column
- `avg(relation, column)` - Average column
- `min(relation, column)` - Minimum value
- `max(relation, column)` - Maximum value

**Execution** (trigger query execution):
- `execute(relation)` - Execute and return result struct
- `fetch_all(relation)` - Execute and fetch all rows
- `fetch_one(relation)` - Execute and fetch first row
- `fetch_many(relation, n)` - Execute and fetch N rows

**Table/View Operations**:
- `create(relation, table_name)` / `to_table/2`
- `create_view(relation, view_name, opts \\ [])` / `to_view/3`
- `insert_into(relation, table_name)`
- `insert(relation, values)`
- `update(relation, set_map, condition \\ nil)`

**Export**:
- `to_csv(relation, path, opts \\ [])`
- `to_parquet(relation, path, opts \\ [])`

### DuckdbEx.Result

- `fetch_all(result)` - Get all rows as list of tuples
- `fetch_one(result)` - Get first row as tuple
- `fetch_many(result, n)` - Get N rows as list of tuples
- `row_count(result)` - Get number of rows
- `columns(result)` - Get column names
- `to_tuples(result)` - Convert rows to tuples

## Architecture

DuckdbEx uses the DuckDB CLI process via erlexec instead of native NIFs:

**Advantages**:
- ✅ Maximum portability (works everywhere DuckDB CLI works)
- ✅ No compilation needed
- ✅ Easy to debug and maintain
- ✅ Handles core SQL features automatically

**Trade-offs**:
- JSON serialization overhead (minimal for analytical queries)
- No zero-copy data transfer
- No native UDF registration or embedded APIs (Arrow/Polars/Nx)

This architecture is ideal for analytical workloads where query execution time dominates, and the JSON overhead is negligible compared to query processing.

## Examples

The `examples/` directory contains 8 comprehensive, runnable examples demonstrating all features:

| Example | Description | Run With |
|---------|-------------|----------|
| `00_quickstart.exs` | Your first DuckDB query | `mix run examples/00_quickstart.exs` |
| `01_basic_queries.exs` | Simple queries, math, strings, dates | `mix run examples/01_basic_queries.exs` |
| `02_tables_and_data.exs` | CREATE, INSERT, UPDATE, DELETE | `mix run examples/02_tables_and_data.exs` |
| `03_transactions.exs` | Transaction management | `mix run examples/03_transactions.exs` |
| `04_relations_api.exs` | Lazy query building | `mix run examples/04_relations_api.exs` |
| `05_csv_parquet_json.exs` | Reading/writing files | `mix run examples/05_csv_parquet_json.exs` |
| `06_analytics_window_functions.exs` | Advanced analytics | `mix run examples/06_analytics_window_functions.exs` |
| `07_persistent_database.exs` | File-based databases | `mix run examples/07_persistent_database.exs` |

See [examples/README.md](examples/README.md) for detailed descriptions and more information.
Run everything with `examples/run_all.sh`.

## Guides

- `docs/guides/installation.md`
- `docs/guides/configuration.md`
- `docs/guides/connections.md`
- `docs/guides/relations.md`
- `docs/guides/data_io.md`
- `docs/guides/types_expressions.md`
- `docs/guides/results.md`
- `docs/guides/errors.md`
- `docs/guides/performance_limitations.md`
- `docs/guides/migration_from_python.md`
- `docs/guides/testing_contributing.md`

## Testing

```bash
# Run all tests
mix test

# Run specific test file
mix test test/duckdb_ex/relation_test.exs

# Run with coverage
mix test --cover

# Run with specific seed
mix test --seed 123456
```

**Current Test Coverage**: 158 tests, 100% pass rate (after performance optimization)

## Development Status

### ✅ Implemented

**Core Connection API**:
- Connection management (connect, close, default connection helpers)
- Query execution (execute, executemany) with parameter binding
- Result fetching (fetch_all, fetch_one, fetch_many)
- Statement parsing (extract_statements)
- DB-API metadata (description, rowcount)
- Cursor/duplicate support (Cursor wrapper)
- Exception hierarchy (27 types)
- Transaction management (begin, commit, rollback, transaction helper)
- Checkpoint support
- Read-only connections

**Relation API - Basic Operations**:
- Relation creation (sql, table, view, values)
- Projections (project)
- Filtering (filter)
- Ordering (order, sort)
- Limiting (limit with offset)
- Lazy evaluation

**Relation API - Aggregations**:
- Generic aggregation (aggregate)
- GROUP BY support
- HAVING clause (via filter after aggregate)
- Convenience methods (count, sum, avg, min, max)
- Custom aggregate expressions (e.g., stddev_pop, variance) via aggregate/2

**Relation API - Advanced**:
- Joins (inner, left, right, outer, cross)
- Set operations (union, intersect, except)
- Distinct operations

**Relation API - Mutations**:
- Create tables/views from relations (create, create_view)
- Insert rows (insert, insert_into)
- Update table relations (update)

**File Format Support**:
- CSV reading/writing (read_csv, to_csv)
- Parquet reading/writing (read_parquet, to_parquet)
- JSON reading (read_json)
- Direct file querying via SQL table functions

**Performance**:
- Optimized query execution (100-200x faster via completion markers)
- Tests run in ~1 second (previously took minutes due to timeouts)

### 📋 Planned (Phase 2+)

- Explorer DataFrame integration
- Prepared statements
- Extensions management
- Streaming results

## Contributing

This project follows strict Test-Driven Development (TDD):

1. **RED**: Write failing tests first
2. **GREEN**: Implement minimal code to pass tests
3. **REFACTOR**: Improve code while keeping tests green
4. **DOCUMENT**: Add comprehensive docs and examples

All contributions should:
- Include comprehensive tests
- Follow existing code style
- Reference Python API where applicable
- Maintain 100% test pass rate

## Comparison with Python API

```python
# Python DuckDB
import duckdb
conn = duckdb.connect()
rel = conn.table('users')
result = (rel
  .filter('age > 25')
  .project(['name', 'email'])
  .order('name')
  .limit(10)
  .fetchall())
```

```elixir
# Elixir DuckDB
{:ok, conn} = DuckdbEx.Connection.connect(:memory)
{:ok, rows} = conn
|> DuckdbEx.Connection.table("users")
|> DuckdbEx.Relation.filter("age > 25")
|> DuckdbEx.Relation.project(["name", "email"])
|> DuckdbEx.Relation.order("name")
|> DuckdbEx.Relation.limit(10)
|> DuckdbEx.Relation.fetch_all()
```

API is intentionally similar for easy migration!

## Performance

DuckdbEx uses a **completion marker approach** for deterministic query completion detection instead of timeouts:

- **100-200x faster** query execution (7-12ms vs 1000-2000ms per query)
- Full test suite runs in **~1 second** (158 tests)
- No arbitrary timeouts or guessing
- Proper error handling for aborted transactions

### How It Works

Instead of waiting for timeouts, we append a marker query after each command:
```sql
-- Your query
SELECT * FROM users;
-- Completion marker (added automatically)
SELECT '__DUCKDB_COMPLETE__' as __status__;
```

When we see the marker in the output, we know DuckDB is done. The marker is stripped before returning results to you.

### Why This Approach

- **Deterministic**: We know exactly when queries complete
- **Fast**: No waiting for arbitrary timeouts
- **Reliable**: Works for all query types (SELECT, DDL, DML)
- **Error-aware**: Special handling for aborted transactions

### Performance Considerations

- DuckDB excels at analytical queries on large datasets
- Relation API allows DuckDB to optimize entire query tree
- JSON overhead is minimal compared to query execution time
- Best for OLAP workloads, not OLTP

## Requirements

- Elixir 1.18+
- Erlang/OTP 27+
- DuckDB CLI installed (PATH or `DUCKDB_PATH`)

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- [DuckDB](https://duckdb.org/) - The amazing analytical database
- [DuckDB Python API](https://duckdb.org/docs/api/python) - API design inspiration
- Community contributors

## Support

For questions and discussions:
- Open an issue on [GitHub](https://github.com/nshkrdotcom/duckdb_ex/issues)
- Check [DuckDB documentation](https://duckdb.org/docs/)
- Review the `docs/` directory for detailed guides

---

**Made with ❤️ for the Elixir and DuckDB communities**
