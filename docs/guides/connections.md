# Connections & Transactions

DuckdbEx exposes a connection API similar to `duckdb-python`.

## Connect

```elixir
{:ok, conn} = DuckdbEx.Connection.connect(:memory)
{:ok, conn} = DuckdbEx.Connection.connect("/tmp/app.duckdb")
```

Default connection:

```elixir
{:ok, _} = DuckdbEx.execute("SELECT 1")
{:ok, rows} = DuckdbEx.fetchall()
```

## Execute & Fetch

`execute/3` returns the connection. Use `execute_result/3` or `fetch_*` to read
results.

```elixir
{:ok, conn} = DuckdbEx.Connection.execute(conn, "CREATE TABLE t (id INT)")
{:ok, result} = DuckdbEx.Connection.execute_result(conn, "SELECT 1 AS id")
rows = DuckdbEx.Result.fetch_all(result)
# rows == [{1}]
```

## Parameter Binding

Supported styles:

```elixir
DuckdbEx.Connection.execute(conn, "SELECT ?::INTEGER", [42])
DuckdbEx.Connection.execute(conn, "SELECT $1::INTEGER", [42])
DuckdbEx.Connection.execute(conn, "SELECT :id::INTEGER", %{id: 42})
```

## executemany

```elixir
DuckdbEx.Connection.executemany(conn, "INSERT INTO t VALUES (?)", [[1], [2], [3]])
```

## Cursors & Duplicates

`cursor/1` and `duplicate/1` return a lightweight cursor wrapper. Closing a
cursor does not close the underlying connection.

```elixir
{:ok, cursor} = DuckdbEx.Connection.cursor(conn)
DuckdbEx.Connection.close(cursor)
```

## Transactions

```elixir
DuckdbEx.Connection.begin(conn)
DuckdbEx.Connection.execute(conn, "INSERT INTO t VALUES (1)")
DuckdbEx.Connection.commit(conn)

DuckdbEx.Connection.transaction(conn, fn tx_conn ->
  DuckdbEx.Connection.execute(tx_conn, "INSERT INTO t VALUES (2)")
end)
```

## Description & Rowcount

```elixir
DuckdbEx.Connection.execute(conn, "SELECT 42 AS answer")
{:ok, description} = DuckdbEx.Connection.description(conn)
rowcount = DuckdbEx.Connection.rowcount(conn)
```
