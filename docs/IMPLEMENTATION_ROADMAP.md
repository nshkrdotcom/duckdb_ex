# DuckDB Elixir Implementation Roadmap

## Phase 0: Project Setup & Infrastructure

### Goals
- Set up development environment
- Configure build system
- Establish testing infrastructure

### Tasks

1. **Rustler Setup**
   - Add Rustler dependency to mix.exs
   - Initialize Rust NIF project structure
   - Configure build system (mix compile.rustler)
   - Set up DuckDB Rust bindings

2. **Docker Development Environment**
   - Create Dockerfile for development
   - Include DuckDB native library
   - Set up build tools (Rust, Elixir, Mix)
   - Create docker-compose.yml for local development

3. **Testing Infrastructure**
   - Configure ExUnit
   - Set up test helpers
   - Add test fixtures (CSV, Parquet, JSON files from Python tests)
   - Configure Mox for mocking
   - Set up CI/CD pipeline basics

4. **Documentation Structure**
   - Initialize ExDoc
   - Create docs/ directory structure
   - Set up documentation templates

### Deliverables
- [ ] Working Rustler NIF skeleton
- [ ] Docker environment that builds successfully
- [ ] Test suite runs (even if empty)
- [ ] Documentation generates

## Phase 1: Core Foundation - Connection & Basic Execution

### Reference
- `duckdb-python/src/duckdb_py/include/duckdb_python/pyconnection/pyconnection.hpp`
- `duckdb-python/src/duckdb_py/pyconnection/`

### Goals
- Basic connection management
- Simple query execution
- Result fetching

### Modules to Implement

1. **DuckdbEx.Native (Rust NIF)**
   ```rust
   // Connection resource
   - new_connection(path, config) -> ConnectionResource
   - close_connection(conn) -> :ok
   - execute(conn, sql, params) -> ResultResource
   - query_df(conn, sql) -> RecordBatch
   ```

2. **DuckdbEx.Connection**
   ```elixir
   - connect(database, opts) -> {:ok, conn} | {:error, reason}
   - close(conn) -> :ok
   - execute(conn, sql, params) -> {:ok, conn} | {:error, reason}
   - execute!(conn, sql, params) -> conn
   ```

3. **DuckdbEx.Result**
   ```elixir
   - fetch_one(result) -> {:ok, row | nil}
   - fetch_all(result) -> {:ok, [row]}
   - fetch_many(result, n) -> {:ok, [row]}
   ```

4. **DuckdbEx.Exceptions**
   ```elixir
   - Define all exception modules
   - Implement error mapping from Rust
   ```

### Tests to Port (from duckdb-python/tests/)
- `tests/fast/test_connection.py` (basic connection tests)
- `tests/fast/test_execute.py` (basic execution)
- Basic fetch tests

### Deliverables
- [ ] Can connect to :memory: database
- [ ] Can execute simple SELECT queries
- [ ] Can fetch results as tuples
- [ ] Proper exception handling
- [ ] All tests passing

## Phase 2: Type System & Data Conversions

### Reference
- `duckdb-python/duckdb/typing/`
- `duckdb-python/src/duckdb_py/typing/`

### Goals
- Complete type system
- Bidirectional type conversions
- Custom type support

### Modules to Implement

1. **DuckdbEx.Type**
   ```elixir
   - Standard type constants
   - Type creation functions (list_type, struct_type, etc.)
   - Type introspection
   ```

2. **DuckdbEx.Native (extend Rust)**
   ```rust
   - Type conversion functions
   - Support for all DuckDB types
   - Decimal handling
   - Interval handling
   - Complex type handling (list, struct, map, union)
   ```

3. **DuckdbEx.Value.Constant**
   ```elixir
   - Value type wrappers matching Python API
   - IntegerValue, StringValue, etc.
   ```

### Tests to Port
- `tests/fast/test_types.py`
- `tests/fast/test_type_annotation.py`
- Type-specific test files

### Deliverables
- [ ] All DuckDB types supported
- [ ] Elixir ↔ DuckDB conversions work
- [ ] Decimal precision preserved
- [ ] Date/time handling correct
- [ ] Complex types (struct, list, map) work
- [ ] All type tests passing

## Phase 3: Relation API & Query Builder

### Reference
- `duckdb-python/src/duckdb_py/include/duckdb_python/pyrelation.hpp`
- `duckdb-python/duckdb/`

### Goals
- Lazy query builder
- Chainable operations
- All relational operations

### Modules to Implement

1. **DuckdbEx.Relation**
   ```elixir
   - Basic operations: project, filter, limit, order, distinct
   - Aggregations: count, sum, avg, min, max, etc.
   - Window functions: row_number, rank, lag, lead, etc.
   - Set operations: union, except, intersect
   - Joins: join, cross
   - Execution: execute, fetch_*
   ```

2. **DuckdbEx.Native (extend Rust)**
   ```rust
   - Relation resource and operations
   - Lazy query building
   - Result materialization
   ```

### Tests to Port
- `tests/fast/relational_api/` (entire directory)
  - test_rapi_query.py
  - test_rapi_aggregations.py
  - test_rapi_windows.py
  - test_joins.py
  - etc.

### Deliverables
- [ ] All basic operations work
- [ ] Aggregations functional
- [ ] Window functions work
- [ ] Joins work correctly
- [ ] Set operations work
- [ ] Method chaining works
- [ ] All relation API tests passing

## Phase 4: Data Source Integration

### Reference
- `duckdb-python/src/duckdb_py/pyconnection/` (read_csv, read_parquet, etc.)

### Goals
- CSV reading/writing
- Parquet reading/writing
- JSON support
- DataFrame integration

### Modules to Implement

1. **DuckdbEx.Connection (extend)**
   ```elixir
   - read_csv(conn, path, opts)
   - read_json(conn, path, opts)
   - read_parquet(conn, path, opts)
   - from_query(conn, sql)
   ```

2. **DuckdbEx.Relation (extend)**
   ```elixir
   - to_csv(rel, path, opts)
   - to_parquet(rel, path, opts)
   ```

### Tests to Port
- `tests/fast/test_csv.py`
- `tests/fast/test_parquet.py`
- `tests/fast/test_json.py`

### Deliverables
- [x] CSV reading works
- [x] CSV writing works
- [x] Parquet reading works
- [x] Parquet writing works
- [x] JSON reading works
- [ ] All data source tests passing

## Phase 5: Arrow Integration

### Reference
- `duckdb-python/src/duckdb_py/arrow/`
- Arrow-related tests

### Goals
- Arrow table support
- Zero-copy data exchange
- RecordBatch support

### Modules to Implement

1. **DuckdbEx.Arrow**
   ```elixir
   - to_arrow_table(rel, opts)
   - from_arrow(conn, arrow_obj)
   - to_record_batch(rel, opts)
   ```

2. **DuckdbEx.Native (extend Rust)**
   ```rust
   - Arrow C Data Interface
   - RecordBatch conversion
   ```

### Tests to Port
- `tests/fast/arrow/` (entire directory)

### Deliverables
- [ ] Arrow table export works
- [ ] Arrow import works
- [ ] RecordBatch support
- [ ] All Arrow tests passing

## Phase 6: Transactions & Advanced Features

### Reference
- Transaction methods in pyconnection.hpp
- UDF-related code

### Goals
- Transaction support
- Prepared statements
- User-defined functions

### Modules to Implement

1. **DuckdbEx.Connection (extend)**
   ```elixir
   - begin(conn)
   - commit(conn)
   - rollback(conn)
   - checkpoint(conn)
   ```

2. **DuckdbEx.Statement**
   ```elixir
   - prepare(conn, sql)
   - bind(stmt, params)
   - execute(stmt)
   ```

3. **DuckdbEx.UDF**
   ```elixir
   - create_function(conn, name, fun, opts)
   - remove_function(conn, name)
   ```

### Tests to Port
- `tests/fast/test_transaction.py`
- `tests/fast/test_prepared.py`
- `tests/fast/udf/` tests

### Deliverables
- [ ] Transactions work correctly
- [ ] Prepared statements functional
- [ ] UDFs can be registered
- [ ] UDFs execute correctly
- [ ] All transaction/UDF tests passing

## Phase 7: Filesystem & Extensions

### Reference
- `duckdb-python/src/duckdb_py/pyfilesystem.cpp`
- Extension loading code

### Goals
- Filesystem abstraction support
- Extension management
- Virtual filesystem integration

### Modules to Implement

1. **DuckdbEx.Filesystem**
   ```elixir
   - register_filesystem(conn, fs)
   - unregister_filesystem(conn, name)
   - list_filesystems(conn)
   ```

2. **DuckdbEx.Extension**
   ```elixir
   - install_extension(conn, name, opts)
   - load_extension(conn, name)
   ```

### Tests to Port
- `tests/fast/test_filesystem.py`
- Extension-related tests

### Deliverables
- [ ] Filesystem registration works
- [ ] Extensions can be installed
- [ ] Extensions can be loaded
- [ ] All filesystem/extension tests passing

## Phase 8: Expression API

### Reference
- `duckdb-python/src/duckdb_py/expression/`

### Goals
- Expression building API
- Type-safe query construction

### Modules to Implement

1. **DuckdbEx.Expression**
   - Base expression module

2. **DuckdbEx.Expression.Column**
3. **DuckdbEx.Expression.Constant**
4. **DuckdbEx.Expression.Function**
5. **DuckdbEx.Expression.Case**
6. **DuckdbEx.Expression.Lambda**

### Tests to Port
- Expression-related tests

### Deliverables
- [ ] Expression API functional
- [ ] Type-safe query building
- [ ] All expression tests passing

## Phase 9: Explorer & Nx Integration

### Reference
- DuckDB-specific, new for Elixir

### Goals
- First-class Explorer support
- Nx tensor support
- Elixir ecosystem integration

### Modules to Implement

1. **DuckdbEx.Explorer**
   ```elixir
   - to_dataframe(rel)
   - from_dataframe(conn, df)
   ```

2. **DuckdbEx.Nx**
   ```elixir
   - to_tensor(rel)
   - from_tensor(conn, tensor, opts)
   ```

### Tests
- Custom Explorer integration tests
- Custom Nx integration tests

### Deliverables
- [ ] Explorer DataFrame conversion works
- [ ] Nx tensor conversion works
- [ ] Integration tests passing

## Phase 10: DBConnection Adapter (Optional)

### Goals
- DBConnection protocol implementation
- Connection pooling
- Ecto compatibility foundation

### Modules to Implement

1. **DuckdbEx.DBConnection**
   - Implement DBConnection behaviour
   - Connection pool support

### Deliverables
- [ ] DBConnection protocol implemented
- [ ] Works with DBConnection.Pool
- [ ] Basic Ecto queries work (without migrations)

## Phase 11: Performance & Optimization

### Goals
- Performance benchmarks
- Memory optimization
- Streaming improvements

### Tasks
- [ ] Benchmark suite
- [ ] Profile memory usage
- [ ] Optimize hot paths
- [ ] Implement streaming for large results
- [ ] Document performance characteristics

### Deliverables
- [ ] Performance benchmarks
- [ ] Optimization guide
- [ ] Memory leak prevention

## Phase 12: Documentation & Polish

### Goals
- Complete documentation
- Examples and guides
- Migration documentation

### Tasks
- [ ] Complete all @moduledoc and @doc
- [ ] Write getting started guide
- [ ] Create cookbook with examples
- [ ] Write migration guide from Python
- [ ] API reference complete
- [ ] Publish on Hex.pm

### Deliverables
- [ ] Full ExDoc documentation
- [ ] Migration guide
- [ ] Cookbook with 20+ examples
- [ ] Package published

## Testing Strategy Per Phase

### Test-Driven Development Approach

For each phase:

1. **Port Python Tests**
   - Identify relevant Python tests from `duckdb-python/tests/`
   - Translate to Elixir/ExUnit
   - Tests should FAIL initially

2. **Create Mocks (if needed)**
   - Use Mox to mock NIF calls during development
   - Allows Elixir-side development before Rust implementation

3. **Implement Rust NIF**
   - Write Rust code to satisfy NIF interface
   - Ensure proper error handling
   - Resource management

4. **Implement Elixir Wrapper**
   - Write Elixir module wrapping NIF calls
   - Add Elixir-idiomatic conveniences
   - Proper error handling and conversion

5. **Run Tests**
   - All ported tests should pass
   - Add additional edge case tests
   - Property-based tests where appropriate

6. **Refactor & Optimize**
   - Code review
   - Performance review
   - Documentation review

### Test Coverage Requirements

- Minimum 90% code coverage
- All public API functions tested
- Error paths tested
- Concurrent access tested
- Memory leak tests

## Dependencies

### Phase Dependencies

- Phase 1 must complete before any other phase
- Phase 2 must complete before Phase 3
- Phases 4-8 can be done in parallel after Phase 3
- Phase 9 requires Phase 4 (for data exchange)
- Phase 10-12 can be done after core phases (1-8)

### External Dependencies

#### Elixir
- Elixir ~> 1.18
- Rustler ~> 0.35
- ExUnit (testing)
- ExDoc (documentation)
- Jason (JSON)
- Decimal (decimal precision)
- Mox (mocking for tests)

#### Rust
- rustler ~> 0.35
- duckdb ~> 1.1
- arrow (for Arrow integration)

#### Development
- Docker
- docker-compose
- DuckDB native library

## Success Criteria

### Per Phase
- All ported tests passing
- No memory leaks
- Documentation complete
- Code review passed

### Overall Project
- 100% API parity with Python client
- All Python tests ported and passing
- Performance within 20% of Python client
- Full documentation
- Published on Hex.pm
- Used in at least one production project

## Risk Management

### Identified Risks

1. **Rust/Elixir boundary complexity**
   - Mitigation: Start simple, iterate
   - Use Rustler best practices
   - Extensive testing of NIF layer

2. **Performance degradation**
   - Mitigation: Continuous benchmarking
   - Profile early and often
   - Zero-copy where possible

3. **API incompleteness**
   - Mitigation: Systematic test porting
   - Check against Python source regularly
   - Track completion percentage

4. **Memory leaks**
   - Mitigation: Valgrind testing
   - Resource lifecycle testing
   - Explicit cleanup in tests

5. **Type system complexity**
   - Mitigation: Phase 2 dedicated to types
   - Comprehensive type tests
   - Reference Python implementation

## Timeline Estimation

Assuming 1 developer full-time:

- Phase 0: 1 week
- Phase 1: 2 weeks
- Phase 2: 2 weeks
- Phase 3: 3 weeks
- Phase 4: 2 weeks
- Phase 5: 2 weeks
- Phase 6: 2 weeks
- Phase 7: 1 week
- Phase 8: 1 week
- Phase 9: 1 week
- Phase 10: 2 weeks (optional)
- Phase 11: 1 week
- Phase 12: 1 week

**Total: ~20 weeks (5 months)**

With multiple developers or part-time work, adjust accordingly.

## Monitoring Progress

### Completion Metrics

Track for each phase:
- [ ] Tests ported: X/Y
- [ ] Tests passing: X/Y
- [ ] Code coverage: X%
- [ ] Documentation: X%
- [ ] Review status: Not started | In review | Approved

### Overall Project Metrics

- Total API functions ported: X/Y
- Total tests ported: X/Y
- Total tests passing: X/Y
- Overall code coverage: X%
- Performance vs Python: X%

## Reference Checklist

Before considering any phase complete:

- [ ] Check corresponding Python source code in `duckdb-python/`
- [ ] Verify all public methods from Python are implemented
- [ ] Verify parameter handling matches Python
- [ ] Verify error handling matches Python
- [ ] Verify type conversions match Python behavior
- [ ] Port all relevant tests from `duckdb-python/tests/`
- [ ] Document differences (if any) from Python API
- [ ] Update TECHNICAL_DESIGN.md if needed
