defmodule DuckdbEx do
  @moduledoc """
  DuckDB Elixir Client - A 100% faithful port of the Python duckdb client.

  This library provides Elixir bindings to DuckDB, an in-process SQL OLAP database
  management system. It mirrors the Python duckdb API for compatibility and ease of migration.

  Reference: duckdb-python for API compatibility

  ## Quick Start

      # Connect to an in-memory database
      {:ok, conn} = DuckdbEx.connect()

      # Execute a query
      {:ok, result} = DuckdbEx.execute(conn, "SELECT 42 as answer")

      # Close the connection
      DuckdbEx.close(conn)

  ## Architecture

  This implementation uses the DuckDB CLI binary managed through erlexec,
  providing a simpler alternative to NIF-based approaches while covering
  core SQL and Relation behaviors.

  ## Modules

  - `DuckdbEx.Connection` - Connection management
  - `DuckdbEx.Port` - DuckDB CLI process management
  - `DuckdbEx.Exceptions` - Exception types

  ## Future Modules (to be implemented)

  - `DuckdbEx.Type` - Type system
  - `DuckdbEx.Expression` - Expression helpers
  """

  alias DuckdbEx.Connection
  alias DuckdbEx.Cursor
  alias DuckdbEx.DefaultConnection

  @doc """
  Opens a connection to a DuckDB database.

  This is a convenience function that delegates to `DuckdbEx.Connection.connect/2`.

  ## Examples

      {:ok, conn} = DuckdbEx.connect()
      {:ok, conn} = DuckdbEx.connect(:memory)
      {:ok, conn} = DuckdbEx.connect("/path/to/db.duckdb")
  """
  defdelegate connect(database \\ :memory, opts \\ []), to: Connection

  @doc """
  Returns the current default connection, creating one if needed.
  """
  def default_connection do
    DefaultConnection.get()
  end

  @doc """
  Sets the default connection used by module-level helpers.
  """
  def set_default_connection(conn) when is_pid(conn) do
    DefaultConnection.set(conn)
  end

  @doc """
  Executes a SQL query.

  This is a convenience function that delegates to `DuckdbEx.Connection.execute/3`.

  ## Examples

      {:ok, conn} = DuckdbEx.connect()
      {:ok, result} = DuckdbEx.execute(conn, "SELECT 1")
  """
  def execute(conn, sql, params) when is_pid(conn) do
    Connection.execute(conn, sql, params)
  end

  def execute(conn, sql) when is_pid(conn) do
    execute(conn, sql, [])
  end

  def execute(sql_or_statement, params) do
    with {:ok, conn} <- default_connection() do
      Connection.execute(conn, sql_or_statement, params)
    end
  end

  def execute(sql_or_statement) do
    execute(sql_or_statement, [])
  end

  def executemany(conn, sql_or_statement, params_list) when is_pid(conn) do
    Connection.executemany(conn, sql_or_statement, params_list)
  end

  def executemany(conn, sql_or_statement) when is_pid(conn) do
    executemany(conn, sql_or_statement, [])
  end

  def executemany(sql_or_statement, params_list) do
    with {:ok, conn} <- default_connection() do
      Connection.executemany(conn, sql_or_statement, params_list)
    end
  end

  def executemany(sql_or_statement) do
    executemany(sql_or_statement, [])
  end

  def fetchall(conn) when is_pid(conn), do: Connection.fetch_all(conn)

  def fetchall do
    with {:ok, conn} <- default_connection() do
      Connection.fetch_all(conn)
    end
  end

  def fetchone(conn) when is_pid(conn), do: Connection.fetch_one(conn)

  def fetchone do
    with {:ok, conn} <- default_connection() do
      Connection.fetch_one(conn)
    end
  end

  def fetchmany(conn, count) when is_pid(conn) and is_integer(count) do
    Connection.fetch_many(conn, count)
  end

  def fetchmany(conn) when is_pid(conn) do
    Connection.fetch_many(conn, 1)
  end

  def fetchmany(count) when is_integer(count) do
    with {:ok, conn} <- default_connection() do
      Connection.fetch_many(conn, count)
    end
  end

  def fetchmany, do: fetchmany(1)

  def description do
    with {:ok, conn} <- default_connection() do
      Connection.description(conn)
    end
  end

  def rowcount do
    with {:ok, conn} <- default_connection() do
      Connection.rowcount(conn)
    end
  end

  def sql(conn, query, params) when is_pid(conn) do
    Connection.sql(conn, query, params)
  end

  def sql(conn, query) when is_pid(conn) do
    sql(conn, query, [])
  end

  def sql(query, params) when is_binary(query) do
    with {:ok, conn} <- default_connection() do
      Connection.sql(conn, query, params)
    end
  end

  def sql(query) when is_binary(query) do
    sql(query, [])
  end

  def query(conn, query, alias, params) when is_pid(conn) do
    Connection.query(conn, query, alias, params)
  end

  def query(conn, query, alias) when is_pid(conn) and is_binary(alias) do
    query(conn, query, alias, [])
  end

  def query(query, alias, params) when is_binary(query) do
    with {:ok, conn} <- default_connection() do
      Connection.query(conn, query, alias, params)
    end
  end

  def query(conn, query) when is_pid(conn) do
    query(conn, query, "", [])
  end

  def query(query, alias) when is_binary(query) and is_binary(alias) do
    query(query, alias, [])
  end

  def query(query) when is_binary(query) do
    query(query, "", [])
  end

  def table(conn, name) when is_pid(conn), do: Connection.table(conn, name)

  def table(name) when is_binary(name) do
    with {:ok, conn} <- default_connection() do
      Connection.table(conn, name)
    end
  end

  def view(conn, name) when is_pid(conn), do: Connection.view(conn, name)

  def view(name) when is_binary(name) do
    with {:ok, conn} <- default_connection() do
      Connection.view(conn, name)
    end
  end

  def values(conn, values) when is_pid(conn), do: Connection.values(conn, values)

  def values(values) do
    with {:ok, conn} <- default_connection() do
      Connection.values(conn, values)
    end
  end

  def read_csv(conn, path, opts) when is_pid(conn) do
    Connection.read_csv(conn, path, opts)
  end

  def read_csv(%Cursor{} = cursor, path, opts) do
    Connection.read_csv(cursor, path, opts)
  end

  def read_csv(conn, path) when is_pid(conn) do
    read_csv(conn, path, [])
  end

  def read_csv(%Cursor{} = cursor, path) do
    read_csv(cursor, path, [])
  end

  def read_csv(path, opts) when is_binary(path) or is_list(path) do
    with {:ok, conn} <- default_connection() do
      Connection.read_csv(conn, path, opts)
    end
  end

  def read_csv(path) do
    read_csv(path, [])
  end

  def read_json(conn, path, opts) when is_pid(conn) do
    Connection.read_json(conn, path, opts)
  end

  def read_json(%Cursor{} = cursor, path, opts) do
    Connection.read_json(cursor, path, opts)
  end

  def read_json(conn, path) when is_pid(conn) do
    read_json(conn, path, [])
  end

  def read_json(%Cursor{} = cursor, path) do
    read_json(cursor, path, [])
  end

  def read_json(path, opts) when is_binary(path) or is_list(path) do
    with {:ok, conn} <- default_connection() do
      Connection.read_json(conn, path, opts)
    end
  end

  def read_json(path) do
    read_json(path, [])
  end

  def read_parquet(conn, path, opts) when is_pid(conn) do
    Connection.read_parquet(conn, path, opts)
  end

  def read_parquet(%Cursor{} = cursor, path, opts) do
    Connection.read_parquet(cursor, path, opts)
  end

  def read_parquet(conn, path) when is_pid(conn) do
    read_parquet(conn, path, [])
  end

  def read_parquet(%Cursor{} = cursor, path) do
    read_parquet(cursor, path, [])
  end

  def read_parquet(path, opts) when is_binary(path) or is_list(path) do
    with {:ok, conn} <- default_connection() do
      Connection.read_parquet(conn, path, opts)
    end
  end

  def read_parquet(path) do
    read_parquet(path, [])
  end

  def cursor(conn) when is_pid(conn), do: Connection.cursor(conn)

  def cursor do
    with {:ok, conn} <- default_connection() do
      Connection.cursor(conn)
    end
  end

  def duplicate(conn) when is_pid(conn), do: Connection.duplicate(conn)

  def duplicate do
    with {:ok, conn} <- default_connection() do
      Connection.duplicate(conn)
    end
  end

  def extract_statements(sql) when is_binary(sql) do
    Connection.extract_statements(sql)
  end

  @doc """
  Closes a database connection.

  This is a convenience function that delegates to `DuckdbEx.Connection.close/1`.

  ## Examples

      {:ok, conn} = DuckdbEx.connect()
      :ok = DuckdbEx.close(conn)
  """
  def close(%Cursor{} = cursor) do
    Connection.close(cursor)
    :ok
  end

  def close(conn) when is_pid(conn) do
    Connection.close(conn)

    case DefaultConnection.peek() do
      {:ok, ^conn} -> DefaultConnection.clear()
      _ -> :ok
    end

    :ok
  end

  def close do
    case DefaultConnection.peek() do
      {:ok, conn} ->
        Connection.close(conn)
        DefaultConnection.clear()
        :ok

      :error ->
        :ok
    end
  end
end
