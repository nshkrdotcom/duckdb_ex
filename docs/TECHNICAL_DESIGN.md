# DuckDB Elixir Port - Technical Design Document

## Overview

This document provides the comprehensive technical design for porting the DuckDB Python client to Elixir. This is a **100% exact port** of the Python client functionality to Elixir, maintaining API parity while following Elixir conventions and idioms.

## Source Reference

**Primary Reference**: `duckdb-python/` directory in this repository

All implementation decisions should reference the Python implementation for:
- API surface area and function signatures
- Behavior and semantics
- Error handling patterns
- Type conversions
- Edge cases and special handling

## Architecture Overview

### Current Implementation (CLI)

DuckdbEx currently uses the DuckDB CLI in JSON mode managed via `erlexec`. The
`DuckdbEx.Port` GenServer owns the CLI process and parses ordered JSON results
into tuple rows. Connections are PIDs; cursors are lightweight wrappers around
the connection PID to avoid extra file locks in the CLI backend.

Environment configuration:
- `DUCKDB_PATH` to locate the CLI binary.
- `DUCKDB_EX_EXEC_AS_ROOT` to force root execution when required in containers.
- `mix duckdb_ex.install` installs the CLI into the project `priv/duckdb/duckdb` and is picked up automatically.

### Core Components

The DuckDB Elixir client mirrors the Python architecture with the following main components:

1. **Connection** (`DuckdbEx.Connection`)
   - Maps to `DuckDBPyConnection` (pyconnection.hpp)
   - Handles database connection lifecycle
   - Manages transactions
   - Executes queries and statements

2. **Relation** (`DuckdbEx.Relation`)
   - Maps to `DuckDBPyRelation` (pyrelation.hpp)
   - Lazy query builder pattern
   - Chainable query operations
   - Result materialization

3. **Result** (`DuckdbEx.Result`)
   - Maps to `DuckDBPyResult` (pyresult.hpp)
   - Query result container
   - Multiple fetch modes
   - Type conversions

4. **Type System** (`DuckdbEx.Type`)
   - Maps to `DuckDBPyType` and related type classes
   - Type creation and introspection
   - Custom type support (enum, decimal, struct, etc.)

5. **Exceptions** (`DuckdbEx.Exceptions`)
   - All DuckDB exception types
   - Maps Python exception hierarchy to Elixir

## Future NIF Layer Design (Not Implemented)

The sections below describe a potential Rustler-based NIF architecture. The
current implementation does **not** use NIFs; it uses the CLI-based port
described above.

### Technology Stack

- **Rustler**: Elixir NIF framework using Rust
- **DuckDB Rust bindings**: Interface to DuckDB C++ library
- **Architecture**: Rust NIF layer between Elixir and DuckDB

### Why Rustler?

1. **Safety**: Memory-safe bindings to C++
2. **Performance**: Near-native performance
3. **Ergonomics**: Better developer experience than C NIFs
4. **Compatibility**: Excellent DuckDB Rust bindings exist

### NIF Module Structure

```
native/duckdb_nif/
├── src/
│   ├── lib.rs              # NIF entry point
│   ├── connection.rs       # Connection resource and methods
│   ├── relation.rs         # Relation resource and methods
│   ├── result.rs           # Result handling
│   ├── types.rs            # Type system
│   ├── exceptions.rs       # Exception mapping
│   ├── conversions.rs      # Elixir ↔ DuckDB type conversions
│   ├── arrow.rs            # Arrow integration
│   └── filesystem.rs       # Filesystem integration
└── Cargo.toml
```

## Module Structure

### Elixir Module Hierarchy

```
lib/duckdb_ex/
├── connection.ex           # Main connection module
├── relation.ex             # Relation/query builder
├── result.ex               # Result handling
├── exceptions.ex           # Exception definitions
├── port.ex                 # DuckDB CLI process management
├── default_connection.ex   # Default connection holder
├── cursor.ex               # Cursor wrapper
├── parameters.ex           # SQL parameter interpolation
├── statement.ex            # Statement metadata
├── statement_type.ex       # Statement type enum
└── expected_result_type.ex # Expected result enum

# Planned modules (not yet implemented)
# - type.ex, expression/*, value/*, arrow/*, etc.
```

## API Surface

### Connection API

The Connection module provides the primary interface to DuckDB. Reference: `duckdb-python/src/duckdb_py/include/duckdb_python/pyconnection/pyconnection.hpp`

```elixir
defmodule DuckdbEx.Connection do
  # Connection Management
  @spec connect(String.t() | :memory, keyword()) :: {:ok, t()} | {:error, term()}
  @spec close(t()) :: :ok
  @spec interrupt(t()) :: :ok

  # Transactions
  @spec begin(t()) :: {:ok, t()} | {:error, term()}
  @spec commit(t()) :: {:ok, t()} | {:error, term()}
  @spec rollback(t()) :: {:ok, t()} | {:error, term()}
  @spec checkpoint(t()) :: {:ok, t()} | {:error, term()}

  # Query Execution
  @spec execute(t(), String.t(), list()) :: {:ok, t()} | {:error, term()}
  @spec execute_many(t(), String.t(), list()) :: {:ok, t()} | {:error, term()}
  @spec query(t(), String.t(), String.t(), list()) :: {:ok, Relation.t()} | {:error, term()}
  @spec sql(t(), String.t(), list()) :: {:ok, Relation.t()} | {:error, term()}

  # Data Sources
  @spec read_csv(t(), String.t() | list(String.t()), keyword()) :: {:ok, Relation.t()}
  @spec read_json(t(), String.t() | list(String.t()), keyword()) :: {:ok, Relation.t()}
  @spec read_parquet(t(), String.t() | list(String.t()), keyword()) :: {:ok, Relation.t()}
  @spec from_arrow(t(), term()) :: {:ok, Relation.t()}
  @spec from_df(t(), term()) :: {:ok, Relation.t()}
  @spec from_query(t(), String.t()) :: {:ok, Relation.t()}

  # Table/View Access
  @spec table(t(), String.t()) :: {:ok, Relation.t()}
  @spec view(t(), String.t()) :: {:ok, Relation.t()}
  @spec values(t(), list()) :: {:ok, Relation.t()}
  @spec table_function(t(), String.t(), list()) :: {:ok, Relation.t()}

  # Schema Operations
  @spec get_table_names(t(), String.t(), boolean()) :: {:ok, list(String.t())}

  # UDF Registration
  @spec create_function(t(), String.t(), (... -> term()), keyword()) :: {:ok, t()}
  @spec remove_function(t(), String.t()) :: {:ok, t()}

  # Type Creation
  @spec map_type(t(), Type.t(), Type.t()) :: Type.t()
  @spec struct_type(t(), keyword()) :: Type.t()
  @spec list_type(t(), Type.t()) :: Type.t()
  @spec array_type(t(), Type.t(), non_neg_integer()) :: Type.t()
  @spec union_type(t(), keyword()) :: Type.t()
  @spec enum_type(t(), String.t(), Type.t(), list()) :: Type.t()
  @spec decimal_type(t(), integer(), integer()) :: Type.t()
  @spec string_type(t(), String.t()) :: Type.t()
  @spec type(t(), String.t()) :: Type.t()

  # Extensions
  @spec install_extension(t(), String.t(), keyword()) :: :ok
  @spec load_extension(t(), String.t()) :: :ok

  # Object Registration
  @spec register(t(), String.t(), term()) :: {:ok, t()}
  @spec unregister(t(), String.t()) :: {:ok, t()}
  @spec append(t(), String.t(), term(), keyword()) :: {:ok, t()}

  # Filesystem
  @spec register_filesystem(t(), term()) :: :ok
  @spec unregister_filesystem(t(), String.t()) :: :ok
  @spec list_filesystems(t()) :: list(String.t())
  @spec filesystem_is_registered(t(), String.t()) :: boolean()

  # Result Fetching (for DBAPI compatibility)
  @spec fetch_one(t()) :: {:ok, tuple() | nil}
  @spec fetch_many(t(), non_neg_integer()) :: {:ok, list(tuple())}
  @spec fetch_all(t()) :: {:ok, list(tuple())}
  @spec fetch_df(t(), keyword()) :: {:ok, term()}
  @spec fetch_arrow(t(), keyword()) :: {:ok, term()}

  # Progress Tracking
  @spec query_progress(t()) :: float()

  # Statement Extraction
  @spec extract_statements(t(), String.t()) :: list(term())
end
```

### Relation API

The Relation module provides the lazy query builder interface. Reference: `duckdb-python/src/duckdb_py/include/duckdb_python/pyrelation.hpp`

```elixir
defmodule DuckdbEx.Relation do
  # Basic Operations
  @spec project(t(), list(String.t())) :: t()
  @spec filter(t(), String.t() | Expression.t()) :: t()
  @spec limit(t(), integer(), integer()) :: t()
  @spec order(t(), String.t()) :: t()
  @spec sort(t(), list(String.t())) :: t()
  @spec distinct(t()) :: t()
  @spec unique(t(), String.t()) :: t()

  # Aggregations
  @spec aggregate(t(), String.t() | list(String.t()), String.t()) :: t()
  @spec count(t(), String.t(), keyword()) :: t()
  @spec sum(t(), String.t(), keyword()) :: t()
  @spec avg(t(), String.t(), keyword()) :: t()
  @spec min(t(), String.t(), keyword()) :: t()
  @spec max(t(), String.t(), keyword()) :: t()
  @spec median(t(), String.t(), keyword()) :: t()
  @spec mode(t(), String.t(), keyword()) :: t()
  @spec stddev(t(), String.t(), keyword()) :: t()
  @spec variance(t(), String.t(), keyword()) :: t()
  @spec first(t(), String.t(), keyword()) :: t()
  @spec last(t(), String.t(), keyword()) :: t()
  @spec list(t(), String.t(), keyword()) :: t()
  @spec string_agg(t(), String.t(), String.t(), keyword()) :: t()

  # Window Functions
  @spec row_number(t(), String.t(), String.t()) :: t()
  @spec rank(t(), String.t(), String.t()) :: t()
  @spec dense_rank(t(), String.t(), String.t()) :: t()
  @spec percent_rank(t(), String.t(), String.t()) :: t()
  @spec cume_dist(t(), String.t(), String.t()) :: t()
  @spec ntile(t(), String.t(), integer(), String.t()) :: t()
  @spec lag(t(), String.t(), String.t(), keyword()) :: t()
  @spec lead(t(), String.t(), String.t(), keyword()) :: t()
  @spec first_value(t(), String.t(), keyword()) :: t()
  @spec last_value(t(), String.t(), keyword()) :: t()
  @spec nth_value(t(), String.t(), String.t(), integer(), keyword()) :: t()

  # Set Operations
  @spec union(t(), t()) :: t()
  @spec except(t(), t()) :: t()
  @spec intersect(t(), t()) :: t()

  # Joins
  @spec join(t(), t(), String.t() | Expression.t(), String.t()) :: t()
  @spec cross(t(), t()) :: t()

  # Transformations
  @spec map(t(), (term() -> term()), keyword()) :: t()

  # Execution & Fetching
  @spec execute(t()) :: t()
  @spec fetch_one(t()) :: {:ok, tuple() | nil}
  @spec fetch_many(t(), non_neg_integer()) :: {:ok, list(tuple())}
  @spec fetch_all(t()) :: {:ok, list(tuple())}
  @spec fetch_df(t(), keyword()) :: {:ok, term()}
  @spec fetch_arrow(t(), keyword()) :: {:ok, term()}
  @spec fetch_record_batch(t(), keyword()) :: {:ok, term()}

  # Export
  @spec to_csv(t(), String.t(), keyword()) :: :ok
  @spec to_parquet(t(), String.t(), keyword()) :: :ok
  @spec to_arrow_table(t(), keyword()) :: {:ok, term()}
  @spec to_arrow_capsule(t(), keyword()) :: {:ok, term()}

  # Table/View Creation
  @spec create_view(t(), String.t(), keyword()) :: t()
  @spec insert_into(t(), String.t()) :: :ok
  @spec insert(t(), list()) :: :ok
  @spec update(t(), keyword(), String.t()) :: :ok
  @spec create(t(), String.t()) :: :ok

  # Introspection
  @spec describe(t()) :: t()
  @spec length(t()) :: non_neg_integer()
  @spec shape(t()) :: {non_neg_integer(), non_neg_integer()}
  @spec columns(t()) :: list(String.t())
  @spec column_types(t()) :: list(String.t())
  @spec description(t()) :: list(tuple())
  @spec type(t()) :: String.t()
  @spec alias(t()) :: String.t()
  @spec set_alias(t(), String.t()) :: t()

  # SQL Generation
  @spec to_sql(t()) :: String.t()
  @spec explain(t(), atom()) :: String.t()

  # Display
  @spec to_string(t()) :: String.t()
  @spec print(t(), keyword()) :: :ok
end
```

### Type System

Reference: `duckdb-python/duckdb/typing/__init__.py` and type-related C++ code

```elixir
defmodule DuckdbEx.Type do
  # Type struct
  defstruct [:id, :internal_type, :metadata]

  # Standard Types (constants)
  @type standard_type ::
    :boolean | :tinyint | :smallint | :integer | :bigint |
    :hugeint | :utinyint | :usmallint | :uinteger | :ubigint |
    :float | :double | :decimal | :varchar | :blob |
    :timestamp | :timestamp_s | :timestamp_ms | :timestamp_ns |
    :date | :time | :interval | :uuid | :json

  # Composite type constructors
  @spec list(t()) :: t()
  @spec array(t(), non_neg_integer()) :: t()
  @spec map(t(), t()) :: t()
  @spec struct(keyword()) :: t()
  @spec union(keyword()) :: t()
  @spec enum(String.t(), t(), list()) :: t()
  @spec decimal(integer(), integer()) :: t()
end
```

### Exception Hierarchy

Reference: `duckdb-python/duckdb/__init__.py` exception imports

```elixir
defmodule DuckdbEx.Exceptions do
  # Base exceptions
  defmodule Error, do: defexception [:message]
  defmodule Warning, do: defexception [:message]

  # Specific exception types
  defmodule DatabaseError, do: defexception [:message]
  defmodule DataError, do: defexception [:message]
  defmodule OperationalError, do: defexception [:message]
  defmodule IntegrityError, do: defexception [:message]
  defmodule InternalError, do: defexception [:message]
  defmodule ProgrammingError, do: defexception [:message]
  defmodule NotSupportedError, do: defexception [:message]

  # DuckDB-specific exceptions
  defmodule BinderException, do: defexception [:message]
  defmodule CatalogException, do: defexception [:message]
  defmodule ConnectionException, do: defexception [:message]
  defmodule ConstraintException, do: defexception [:message]
  defmodule ConversionException, do: defexception [:message]
  defmodule DependencyException, do: defexception [:message]
  defmodule FatalException, do: defexception [:message]
  defmodule HTTPException, do: defexception [:message]
  defmodule InternalException, do: defexception [:message]
  defmodule InterruptException, do: defexception [:message]
  defmodule InvalidInputException, do: defexception [:message]
  defmodule InvalidTypeException, do: defexception [:message]
  defmodule IOException, do: defexception [:message]
  defmodule NotImplementedException, do: defexception [:message]
  defmodule OutOfMemoryException, do: defexception [:message]
  defmodule OutOfRangeException, do: defexception [:message]
  defmodule ParserException, do: defexception [:message]
  defmodule PermissionException, do: defexception [:message]
  defmodule SequenceException, do: defexception [:message]
  defmodule SerializationException, do: defexception [:message]
  defmodule SyntaxException, do: defexception [:message]
  defmodule TransactionException, do: defexception [:message]
  defmodule TypeMismatchException, do: defexception [:message]
end
```

## Data Type Mapping

### DuckDB → Elixir Type Conversions

| DuckDB Type | Elixir Type | Notes |
|-------------|-------------|-------|
| BOOLEAN | boolean() | Direct mapping |
| TINYINT/SMALLINT/INTEGER | integer() | Arbitrary precision |
| BIGINT | integer() | Arbitrary precision |
| HUGEINT | integer() | Arbitrary precision |
| FLOAT/DOUBLE | float() | IEEE 754 |
| DECIMAL | Decimal.t() | Use Decimal library |
| VARCHAR/TEXT | String.t() | UTF-8 strings |
| BLOB | binary() | Raw bytes |
| DATE | Date.t() | Elixir Date |
| TIME | Time.t() | Elixir Time |
| TIMESTAMP | DateTime.t() / NaiveDateTime.t() | With/without timezone |
| INTERVAL | DuckdbEx.Interval.t() | Custom struct |
| UUID | String.t() | String representation |
| JSON | term() | Decoded JSON via Jason |
| LIST | list() | Elixir lists |
| STRUCT | map() | Elixir maps |
| MAP | %{} | Elixir maps |
| UNION | tagged tuple | {tag, value} |
| ENUM | atom() or String.t() | Configurable |

### Parameter Binding

Support both positional and named parameters:

```elixir
# Positional
DuckdbEx.Connection.execute(conn, "SELECT * FROM users WHERE id = ?", [42])

# Named (similar to Python)
DuckdbEx.Connection.execute(conn, "SELECT * FROM users WHERE id = :id", [id: 42])
```

## Module-Level API (Default Connection)

Reference: `duckdb-python/duckdb/__init__.py` for module-level functions

```elixir
defmodule DuckdbEx do
  # Default connection management
  @spec default_connection() :: Connection.t()
  @spec set_default_connection(Connection.t()) :: :ok

  # Convenience functions using default connection
  @spec connect(String.t() | :memory, keyword()) :: {:ok, Connection.t()}
  @spec close() :: :ok
  @spec execute(String.t(), list()) :: {:ok, Connection.t()}
  @spec query(String.t(), list()) :: {:ok, Relation.t()}
  @spec sql(String.t(), list()) :: {:ok, Relation.t()}
  @spec read_csv(String.t(), keyword()) :: {:ok, Relation.t()}
  @spec read_json(String.t(), keyword()) :: {:ok, Relation.t()}
  @spec read_parquet(String.t(), keyword()) :: {:ok, Relation.t()}
  @spec table(String.t()) :: {:ok, Relation.t()}
  @spec values(list()) :: {:ok, Relation.t()}
end
```

## Resource Management

### NIF Resources

Use Rustler resources for:

1. **Connection Resource**: Wraps DuckDB connection handle
2. **Relation Resource**: Wraps DuckDB relation handle
3. **Result Resource**: Wraps query results

```rust
// Example resource definition
#[derive(NifStruct)]
#[module = "DuckdbEx.Native.Connection"]
pub struct ConnectionResource {
    // Internal DuckDB connection
    inner: Arc<Mutex<duckdb::Connection>>,
}

#[derive(NifStruct)]
#[module = "DuckdbEx.Native.Relation"]
pub struct RelationResource {
    inner: Arc<Mutex<duckdb::Relation>>,
    connection: ConnectionResource,
}
```

### Resource Lifecycle

- Resources cleaned up by BEAM GC
- Explicit close() methods for deterministic cleanup
- Connection pool support for multiple connections

## Error Handling Strategy

### NIF Error Propagation

```rust
// In Rust NIF
fn execute_query(conn: ResourceArc<ConnectionResource>, query: String)
    -> Result<RelationResource, Error> {
    conn.inner.lock()
        .execute(&query)
        .map(|rel| RelationResource::new(rel, conn.clone()))
        .map_err(|e| Error::DatabaseError(e.to_string()))
}
```

### Elixir Error Handling

```elixir
# Pattern 1: {:ok, result} | {:error, exception}
case DuckdbEx.Connection.execute(conn, "SELECT * FROM invalid") do
  {:ok, result} -> process(result)
  {:error, %DuckdbEx.Exceptions.CatalogException{} = e} ->
    Logger.error("Table not found: #{e.message}")
end

# Pattern 2: Raise on error (bang methods)
result = DuckdbEx.Connection.execute!(conn, "SELECT * FROM users")
```

## Testing Strategy

### Test Structure

Reference: `duckdb-python/tests/` for comprehensive test coverage

```
test/
├── duckdb_ex_test.exs              # Module-level API tests
├── connection_test.exs             # Connection tests
├── relation_test.exs               # Relation/query builder tests
├── result_test.exs                 # Result handling tests
├── type_test.exs                   # Type system tests
├── exception_test.exs              # Exception handling tests
├── integration/
│   ├── csv_test.exs               # CSV reading/writing
│   ├── parquet_test.exs           # Parquet integration
│   ├── arrow_test.exs             # Arrow integration
│   ├── transaction_test.exs       # Transaction tests
│   ├── udf_test.exs               # User-defined functions
│   └── filesystem_test.exs        # Filesystem integration
└── support/
    ├── test_helper.exs
    └── fixtures/
        ├── test.csv
        ├── test.parquet
        └── test.json
```

### Test Patterns

1. **Property-based testing** (StreamData)
2. **Comparison testing** against Python client
3. **Integration tests** with real DuckDB operations
4. **Concurrent access tests**
5. **Memory leak detection**

## Integration Points

### Arrow Integration

Support Apache Arrow for zero-copy data exchange:

```elixir
defmodule DuckdbEx.Arrow do
  @spec to_arrow_table(Relation.t(), keyword()) :: {:ok, term()}
  @spec from_arrow(Connection.t(), term()) :: {:ok, Relation.t()}
  @spec to_arrow_capsule(Relation.t()) :: {:ok, term()}
end
```

### Explorer Integration

Provide first-class integration with Elixir's Explorer library:

```elixir
defmodule DuckdbEx.Explorer do
  @spec to_dataframe(Relation.t()) :: Explorer.DataFrame.t()
  @spec from_dataframe(Connection.t(), Explorer.DataFrame.t()) :: Relation.t()
end
```

### Nx Integration

Support Nx tensors for numerical computing:

```elixir
defmodule DuckdbEx.Nx do
  @spec to_tensor(Relation.t()) :: Nx.Tensor.t()
  @spec from_tensor(Connection.t(), Nx.Tensor.t(), keyword()) :: Relation.t()
end
```

## Performance Considerations

### Optimization Strategies

1. **Lazy Evaluation**: Relations build query plans without execution
2. **Streaming Results**: Support for chunked result fetching
3. **Zero-Copy**: Use Arrow for data transfer where possible
4. **Connection Pooling**: DBConnection-compatible pool
5. **Prepared Statements**: Cache compiled queries
6. **Batch Operations**: Efficient bulk inserts

### Benchmarking

Compare performance against:
- Python duckdb client
- PostgreSQL (Postgrex)
- SQLite (Exqlite)

## Security Considerations

1. **SQL Injection**: Use parameterized queries exclusively
2. **Resource Limits**: Configurable memory limits
3. **Path Traversal**: Validate file paths for read_csv, etc.
4. **Extension Loading**: Optional restrictions on loading extensions

## Configuration

```elixir
# config/config.exs
config :duckdb_ex,
  default_connection: [
    database: ":memory:",
    config: [
      threads: 4,
      max_memory: "1GB",
      temp_directory: "/tmp/duckdb"
    ]
  ],
  pool: [
    size: 10,
    max_overflow: 5
  ]
```

## Migration from Python

### API Compatibility Table

| Python API | Elixir API | Notes |
|------------|------------|-------|
| `duckdb.connect()` | `DuckdbEx.connect()` | Returns {:ok, conn} tuple |
| `con.execute()` | `Connection.execute()` | Same parameters |
| `con.sql()` | `Connection.sql()` | Returns Relation |
| `rel.filter()` | `Relation.filter()` | Chainable |
| `rel.fetchall()` | `Relation.fetch_all()` | Returns {:ok, list} |
| `duckdb.read_csv()` | `DuckdbEx.read_csv()` | Same options |

### Migration Guide

Document to be created showing side-by-side examples of Python vs Elixir code.

## Documentation Requirements

1. **ExDoc**: Complete module and function documentation
2. **Guides**: Getting started, cookbook, migration guide
3. **Examples**: Real-world usage examples
4. **Changelog**: Track changes and version compatibility
5. **Type Specs**: Complete @spec for all public functions

## Future Enhancements

1. **Ecto Adapter**: Full Ecto integration
2. **Phoenix Integration**: LiveView components
3. **Telemetry**: Instrumentation for observability
4. **Distributed Queries**: Multi-node query execution
5. **Custom Extensions**: Elixir-based DuckDB extensions

## References

- DuckDB Python source: `duckdb-python/` directory
- DuckDB Documentation: https://duckdb.org/docs
- DuckDB Rust: https://github.com/duckdb/duckdb-rs
- Rustler: https://github.com/rusterlium/rustler
- DB Connection: https://github.com/elixir-ecto/db_connection
