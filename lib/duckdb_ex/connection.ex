defmodule DuckdbEx.Connection do
  @moduledoc """
  DuckDB connection management.

  This module provides the primary interface to DuckDB databases, mirroring the
  functionality of the Python DuckDBPyConnection class.

  Reference: duckdb-python/src/duckdb_py/include/duckdb_python/pyconnection/pyconnection.hpp

  ## Overview

  A connection represents an active session with a DuckDB database using the
  DuckDB CLI managed through erlexec. Connections can be:
  - In-memory (`:memory:`)
  - Persistent (file path)
  - Read-only or read-write

  ## Examples

      # Connect to an in-memory database
      {:ok, conn} = DuckdbEx.Connection.connect(:memory)

      # Execute a query
      {:ok, result} = DuckdbEx.Connection.execute(conn, "SELECT 1")

      # Close connection
      DuckdbEx.Connection.close(conn)
  """

  alias DuckdbEx.Cursor
  alias DuckdbEx.DefaultConnection
  alias DuckdbEx.Exceptions
  alias DuckdbEx.ExpectedResultType
  alias DuckdbEx.Parameters
  alias DuckdbEx.Port
  alias DuckdbEx.Relation
  alias DuckdbEx.Result
  alias DuckdbEx.Statement
  alias DuckdbEx.StatementType

  @type t :: Port.t() | Cursor.t()

  @read_csv_option_map %{
    "delimiter" => "delim",
    "sep" => "sep",
    "dtype" => "types",
    "dtypes" => "types",
    "na_values" => "nullstr",
    "skiprows" => "skip",
    "quotechar" => "quote",
    "escapechar" => "escape",
    "date_format" => "dateformat",
    "timestamp_format" => "timestampformat"
  }

  @read_json_option_map %{
    "date_format" => "dateformat",
    "timestamp_format" => "timestampformat"
  }

  @read_parquet_option_map %{}

  @doc """
  Opens a connection to a DuckDB database.

  ## Parameters

  - `database` - Database path or `:memory:` for in-memory database
  - `opts` - Connection options (keyword list)
    - `:read_only` - Open in read-only mode (default: false)
    - `:config` - Database configuration map (for future use)

  ## Returns

  - `{:ok, conn}` - Successfully opened connection
  - `{:error, exception}` - Connection failed

  ## Examples

      {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      {:ok, conn} = DuckdbEx.Connection.connect("/path/to/db.duckdb")
      {:ok, conn} = DuckdbEx.Connection.connect(:memory, read_only: true)

  Reference: duckdb.connect() in Python
  """
  @spec connect(String.t() | :memory | :default, keyword()) :: {:ok, t()} | {:error, term()}
  def connect(database \\ :memory, opts \\ []) do
    case database do
      :default ->
        connect_default(opts)

      ":default:" ->
        connect_default(opts)

      _ ->
        port_opts = Keyword.put(opts, :database, database)
        Port.start_link(port_opts)
    end
  end

  defp connect_default(opts) do
    if opts == [] do
      DefaultConnection.get()
    else
      {:error,
       %Exceptions.InvalidInputException{
         message: "Default connection fetching is only allowed without additional options"
       }}
    end
  end

  @doc """
  Executes a SQL query.

  ## Parameters

  - `conn` - The connection
  - `sql` - SQL query string
  - `params` - Query parameters (not yet implemented)

  ## Returns

  - `{:ok, result}` - Query executed successfully
  - `{:error, exception}` - Query failed

  ## Examples

      {:ok, result} = DuckdbEx.Connection.execute(conn, "SELECT 1")

  Reference: DuckDBPyConnection.execute() in Python
  """
  @spec execute(t(), String.t() | Statement.t(), list() | map()) :: {:ok, t()} | {:error, term()}
  def execute(conn, sql_or_statement, params \\ [])

  def execute(conn, %Statement{} = statement, params) do
    conn = unwrap_conn(conn)

    with {:ok, sql} <- prepare_statement(statement, params),
         {:ok, _result} <- Port.execute(conn, sql) do
      {:ok, conn}
    end
  end

  def execute(conn, sql, params) when is_binary(sql) do
    conn = unwrap_conn(conn)

    with {:ok, final_sql} <- Parameters.interpolate(sql, params),
         {:ok, _result} <- Port.execute(conn, final_sql) do
      {:ok, conn}
    end
  end

  @spec execute_result(t(), String.t() | Statement.t(), list() | map()) ::
          {:ok, map()} | {:error, term()}
  def execute_result(conn, sql_or_statement, params \\ [])

  def execute_result(conn, %Statement{} = statement, params) do
    conn = unwrap_conn(conn)

    case prepare_statement(statement, params) do
      {:ok, sql} -> Port.execute(conn, sql)
      {:error, _} = error -> error
    end
  end

  def execute_result(conn, sql, params) when is_binary(sql) do
    conn = unwrap_conn(conn)

    case Parameters.interpolate(sql, params) do
      {:ok, final_sql} -> Port.execute(conn, final_sql)
      {:error, _} = error -> error
    end
  end

  @doc """
  Executes a SQL query multiple times with different parameter sets.
  """
  @spec executemany(t(), String.t() | Statement.t(), list()) :: {:ok, t()} | {:error, term()}
  def executemany(conn, sql_or_statement, params_list \\ [])

  def executemany(_conn, _sql, params_list) when params_list in [nil, []] do
    {:error,
     %Exceptions.InvalidInputException{
       message: "executemany requires a non-empty list of parameter sets to be provided"
     }}
  end

  def executemany(conn, sql_or_statement, params_list) when is_list(params_list) do
    Enum.reduce_while(params_list, {:ok, conn}, fn params, _acc ->
      case execute_result(conn, sql_or_statement, params) do
        {:ok, _} -> {:cont, {:ok, conn}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  def executemany(_conn, _sql, _params) do
    {:error,
     %Exceptions.InvalidInputException{
       message: "executemany requires a list of parameter sets to be provided"
     }}
  end

  @doc """
  Fetches all rows from a query result.

  This is a convenience function that executes a query and returns all rows.

  ## Parameters

  - `conn` - The connection
  - `sql` - SQL query string

  ## Returns

  - `{:ok, rows}` - List of row tuples
  - `{:error, exception}` - Query failed

  ## Examples

      {:ok, rows} = DuckdbEx.Connection.fetch_all(conn, "SELECT * FROM users")

  Reference: DuckDBPyConnection.execute().fetchall() in Python
  """
  @spec fetch_all(t()) :: {:ok, list(tuple())} | {:error, term()}
  def fetch_all(conn) do
    with {:ok, result} <- last_result(conn) do
      {:ok, Result.fetch_all(result)}
    end
  end

  @spec fetch_all(t(), String.t()) :: {:ok, list(tuple())} | {:error, term()}
  def fetch_all(conn, sql) when is_binary(sql) do
    with {:ok, result} <- execute_result(conn, sql) do
      {:ok, Result.fetch_all(result)}
    end
  end

  def fetchall(conn), do: fetch_all(conn)

  @doc """
  Fetches one row from a query result.

  This is a convenience function that executes a query and returns the first row.

  ## Parameters

  - `conn` - The connection
  - `sql` - SQL query string

  ## Returns

  - `{:ok, row}` - Row tuple or nil
  - `{:error, exception}` - Query failed

  ## Examples

      {:ok, row} = DuckdbEx.Connection.fetch_one(conn, "SELECT * FROM users LIMIT 1")

  Reference: DuckDBPyConnection.execute().fetchone() in Python
  """
  @spec fetch_one(t()) :: {:ok, tuple() | nil} | {:error, term()}
  def fetch_one(conn) do
    with {:ok, result} <- last_result(conn) do
      {:ok, Result.fetch_one(result)}
    end
  end

  @spec fetch_one(t(), String.t()) :: {:ok, tuple() | nil} | {:error, term()}
  def fetch_one(conn, sql) when is_binary(sql) do
    with {:ok, result} <- execute_result(conn, sql) do
      {:ok, Result.fetch_one(result)}
    end
  end

  def fetchone(conn), do: fetch_one(conn)

  @doc """
  Fetches multiple rows from the last result.

  ## Parameters

  - `conn` - The connection
  - `count` - Number of rows to fetch (default: 1)
  """
  @spec fetch_many(t(), non_neg_integer()) :: {:ok, list(tuple())} | {:error, term()}
  def fetch_many(conn, count \\ 1) when is_integer(count) and count >= 0 do
    with {:ok, result} <- last_result(conn) do
      {:ok, Result.fetch_many(result, count)}
    end
  end

  @spec fetch_many(t(), String.t(), non_neg_integer()) :: {:ok, list(tuple())} | {:error, term()}
  def fetch_many(conn, sql, count) when is_binary(sql) and is_integer(count) and count >= 0 do
    with {:ok, result} <- execute_result(conn, sql) do
      {:ok, Result.fetch_many(result, count)}
    end
  end

  def fetchmany(conn, count \\ 1), do: fetch_many(conn, count)

  @doc """
  Returns the description of the last executed result set.
  """
  @spec description(t()) :: {:ok, list(tuple()) | nil} | {:error, term()}
  def description(conn) do
    conn = unwrap_conn(conn)

    case Port.last_result(conn) do
      {:ok, nil} ->
        {:ok, nil}

      {:ok, result} ->
        {:ok, describe_result(conn, result)}
    end
  end

  @doc """
  Returns the rowcount for the last result set.
  """
  @spec rowcount(t()) :: integer()
  def rowcount(_conn), do: -1

  @doc """
  Creates a duplicate of the current connection.
  """
  @spec cursor(t()) :: {:ok, t()} | {:error, term()}
  def cursor(conn) do
    {:ok, %Cursor{conn: unwrap_conn(conn)}}
  end

  @spec duplicate(t()) :: {:ok, t()} | {:error, term()}
  def duplicate(conn), do: cursor(conn)

  @doc """
  Extracts statements from a SQL string.
  """
  @spec extract_statements(String.t()) :: {:ok, list(Statement.t())} | {:error, term()}
  def extract_statements(sql) when is_binary(sql) do
    parse_statements(sql)
  end

  @spec extract_statements(t(), String.t()) :: {:ok, list(Statement.t())} | {:error, term()}
  def extract_statements(_conn, sql) when is_binary(sql) do
    extract_statements(sql)
  end

  @doc """
  Creates a relation from a SQL query.

  Returns a lazy relation that can be composed with other operations before
  execution. The SQL is not executed until a fetch operation is called.

  ## Parameters

  - `conn` - The connection
  - `sql` - SQL query string

  ## Returns

  A `%DuckdbEx.Relation{}` struct

  ## Examples

      # Create relation (not executed yet)
      relation = DuckdbEx.Connection.sql(conn, "SELECT * FROM users")

      # Chain operations
      result = relation
      |> DuckdbEx.Relation.filter("age > 25")
      |> DuckdbEx.Relation.fetch_all()

  Reference: DuckDBPyConnection.sql() in Python
  """
  @spec sql(t(), String.t(), list() | map()) :: Relation.t()
  def sql(conn, sql, params \\ []) when is_binary(sql) do
    case Parameters.interpolate(sql, params) do
      {:ok, final_sql} -> Relation.new(conn, final_sql, nil, :query)
      {:error, exception} -> raise exception
    end
  end

  @doc """
  Creates a relation from a SQL query with an optional alias.
  """
  @spec query(t(), String.t(), String.t(), list() | map()) :: Relation.t()
  def query(conn, sql, relation_alias \\ "", params \\ []) when is_binary(sql) do
    case Parameters.interpolate(sql, params) do
      {:ok, final_sql} -> Relation.new(conn, final_sql, relation_alias, :query)
      {:error, exception} -> raise exception
    end
  end

  @doc """
  Creates a relation from a table or view name.

  Returns a lazy relation representing the entire table or view. The table
  is not queried until a fetch operation is called.

  ## Parameters

  - `conn` - The connection
  - `table_name` - Name of the table or view

  ## Returns

  A `%DuckdbEx.Relation{}` struct

  ## Examples

      # Create relation from table
      relation = DuckdbEx.Connection.table(conn, "users")

      # Chain operations
      active_users = relation
      |> DuckdbEx.Relation.filter("status = 'active'")
      |> DuckdbEx.Relation.fetch_all()

  Reference: DuckDBPyConnection.table() in Python
  """
  @spec table(t(), String.t()) :: Relation.t()
  def table(conn, table_name) when is_binary(table_name) do
    sql = "SELECT * FROM #{table_name}"
    Relation.new(conn, sql, table_name, {:table, table_name})
  end

  @doc """
  Creates a relation from a view name.
  """
  @spec view(t(), String.t()) :: Relation.t()
  def view(conn, view_name) when is_binary(view_name) do
    sql = "SELECT * FROM #{view_name}"
    Relation.new(conn, sql, view_name, {:view, view_name})
  end

  @doc """
  Creates a relation from values.

  A list of values is treated as a single row, while a list of tuples/lists
  is treated as multiple rows.
  """
  @spec values(t(), term()) :: Relation.t()
  def values(conn, values) do
    case build_values_rows(values) do
      {:ok, rows_sql} ->
        sql = "SELECT * FROM (VALUES #{rows_sql})"
        Relation.new(conn, sql, nil, :values)

      {:error, exception} ->
        raise exception
    end
  end

  @doc """
  Creates a relation from a CSV file or list of files.
  """
  @spec read_csv(t(), String.t() | list(), keyword() | map()) :: Relation.t()
  def read_csv(conn, path_or_paths, opts \\ []) do
    opts = normalize_opts(opts)
    validate_read_csv_opts!(opts)

    sql = build_table_function_sql("read_csv", path_or_paths, opts, @read_csv_option_map)
    Relation.new(conn, sql)
  end

  @doc """
  Creates a relation from a JSON file or list of files.
  """
  @spec read_json(t(), String.t() | list(), keyword() | map()) :: Relation.t()
  def read_json(conn, path_or_paths, opts \\ []) do
    opts = normalize_opts(opts)
    sql = build_table_function_sql("read_json", path_or_paths, opts, @read_json_option_map)
    Relation.new(conn, sql)
  end

  @doc """
  Creates a relation from a Parquet file or list of files.
  """
  @spec read_parquet(t(), String.t() | list(), keyword() | map()) :: Relation.t()
  def read_parquet(conn, path_or_paths, opts \\ []) do
    opts = normalize_opts(opts)
    sql = build_table_function_sql("read_parquet", path_or_paths, opts, @read_parquet_option_map)
    Relation.new(conn, sql)
  end

  @doc """
  Begins a transaction.

  Starts a new transaction on the connection. All subsequent queries will be
  executed within the transaction context until commit or rollback is called.

  ## Parameters

  - `conn` - The connection

  ## Returns

  - `{:ok, result}` - Transaction started successfully
  - `{:error, exception}` - Failed to start transaction

  ## Examples

      {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      {:ok, _} = DuckdbEx.Connection.begin(conn)
      {:ok, _} = DuckdbEx.Connection.execute(conn, "INSERT INTO users VALUES (1, 'Alice')")
      {:ok, _} = DuckdbEx.Connection.commit(conn)

  Reference: DuckDBPyConnection.begin() in Python
  """
  @spec begin(t()) :: {:ok, term()} | {:error, term()}
  def begin(conn) do
    execute(conn, "BEGIN TRANSACTION")
  end

  @doc """
  Commits the current transaction.

  Commits all changes made within the current transaction, making them permanent.

  ## Parameters

  - `conn` - The connection

  ## Returns

  - `{:ok, result}` - Transaction committed successfully
  - `{:error, exception}` - Failed to commit transaction

  ## Examples

      {:ok, _} = DuckdbEx.Connection.begin(conn)
      {:ok, _} = DuckdbEx.Connection.execute(conn, "INSERT INTO users VALUES (1, 'Alice')")
      {:ok, _} = DuckdbEx.Connection.commit(conn)

  Reference: DuckDBPyConnection.commit() in Python
  """
  @spec commit(t()) :: {:ok, term()} | {:error, term()}
  def commit(conn) do
    execute(conn, "COMMIT")
  end

  @doc """
  Rolls back the current transaction.

  Reverts all changes made within the current transaction.

  ## Parameters

  - `conn` - The connection

  ## Returns

  - `{:ok, result}` - Transaction rolled back successfully
  - `{:error, exception}` - Failed to rollback transaction

  ## Examples

      {:ok, _} = DuckdbEx.Connection.begin(conn)
      {:ok, _} = DuckdbEx.Connection.execute(conn, "INSERT INTO users VALUES (1, 'Alice')")
      {:ok, _} = DuckdbEx.Connection.rollback(conn)

  Reference: DuckDBPyConnection.rollback() in Python
  """
  @spec rollback(t()) :: {:ok, term()} | {:error, term()}
  def rollback(conn) do
    execute(conn, "ROLLBACK")
  end

  @doc """
  Executes a function within a managed transaction.

  This is the recommended way to use transactions. The function is executed
  within a transaction context. If the function completes successfully, the
  transaction is committed. If an exception is raised or an error occurs, the
  transaction is automatically rolled back.

  ## Parameters

  - `conn` - The connection
  - `fun` - A function that takes the connection as an argument

  ## Returns

  - `{:ok, result}` - Transaction completed successfully, returns the function's result
  - `{:error, exception}` - Transaction failed or was rolled back

  ## Examples

      # Successful transaction
      {:ok, result} = DuckdbEx.Connection.transaction(conn, fn conn ->
        {:ok, _} = DuckdbEx.Connection.execute(conn, "INSERT INTO users VALUES (1, 'Alice')")
        {:ok, _} = DuckdbEx.Connection.execute(conn, "INSERT INTO users VALUES (2, 'Bob')")
        :success
      end)

      # Transaction with automatic rollback on error
      {:error, _} = DuckdbEx.Connection.transaction(conn, fn conn ->
        {:ok, _} = DuckdbEx.Connection.execute(conn, "INSERT INTO users VALUES (1, 'Alice')")
        raise "Something went wrong!"
      end)

  Reference: Similar to Python context manager pattern with DuckDB transactions
  """
  @spec transaction(t(), (t() -> term())) :: {:ok, term()} | {:error, term()}
  def transaction(conn, fun) when is_function(fun, 1) do
    case begin(conn) do
      {:ok, _} ->
        try do
          result = fun.(conn)

          # Check if the result is an error tuple - if so, rollback
          case result do
            {:error, _} = error ->
              rollback(conn)
              error

            _ ->
              case commit(conn) do
                {:ok, _} -> {:ok, result}
                error -> error
              end
          end
        rescue
          exception ->
            rollback(conn)
            {:error, exception}
        end

      error ->
        error
    end
  end

  @doc """
  Creates a checkpoint.

  Forces a checkpoint of the write-ahead log (WAL) to the database file.
  This ensures all changes are persisted to disk.

  ## Parameters

  - `conn` - The connection

  ## Returns

  - `{:ok, result}` - Checkpoint created successfully
  - `{:error, exception}` - Failed to create checkpoint

  ## Examples

      {:ok, _} = DuckdbEx.Connection.checkpoint(conn)

  Reference: DuckDBPyConnection.checkpoint() in Python
  """
  @spec checkpoint(t()) :: {:ok, term()} | {:error, term()}
  def checkpoint(conn) do
    execute(conn, "CHECKPOINT")
  end

  defp unwrap_conn(%Cursor{conn: conn}), do: conn
  defp unwrap_conn(conn) when is_pid(conn), do: conn

  defp last_result(conn) do
    conn = unwrap_conn(conn)

    case Port.last_result(conn) do
      {:ok, nil} ->
        {:error, %Exceptions.InvalidInputException{message: "There is no query result"}}

      {:ok, result} ->
        {:ok, result}
    end
  end

  defp describe_result(conn, result) do
    columns = Result.columns(result) || []

    case Port.last_sql(conn) do
      {:ok, sql} when is_binary(sql) ->
        case describe_sql(conn, sql) do
          {:ok, description} when is_list(description) and description != [] ->
            description

          _ ->
            fallback_description(columns)
        end

      _ ->
        fallback_description(columns)
    end
  end

  defp describe_sql(conn, sql) do
    case Port.execute(conn, "DESCRIBE " <> sql, capture_result: false) do
      {:ok, result} ->
        description =
          result
          |> Result.fetch_all()
          |> Enum.map(&describe_row/1)

        {:ok, description}

      error ->
        error
    end
  end

  defp describe_row(row) when is_tuple(row) and tuple_size(row) >= 2 do
    {elem(row, 0), elem(row, 1), nil, nil, nil, nil, nil}
  end

  defp describe_row(row) when is_tuple(row) do
    {elem(row, 0), "UNKNOWN", nil, nil, nil, nil, nil}
  end

  defp fallback_description([]), do: nil

  defp fallback_description(columns) do
    Enum.map(columns, fn name ->
      {name, "UNKNOWN", nil, nil, nil, nil, nil}
    end)
  end

  defp prepare_statement(%Statement{query: query, named_parameters: names}, params) do
    if MapSet.size(names) > 0 and params in [nil, [], %{}] do
      missing =
        names
        |> Enum.sort()
        |> Enum.join(", ")

      {:error,
       %Exceptions.InvalidInputException{
         message:
           "Values were not provided for the following prepared statement parameters: #{missing}"
       }}
    else
      Parameters.interpolate(query, params)
    end
  end

  defp normalize_opts(nil), do: []

  defp normalize_opts(opts) when is_list(opts) do
    Enum.map(opts, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_opts(opts) when is_map(opts) do
    opts
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
  end

  defp validate_read_csv_opts!(opts) do
    has_delimiter = Enum.any?(opts, fn {key, _} -> key == "delimiter" end)
    has_sep = Enum.any?(opts, fn {key, _} -> key == "sep" end)

    if has_delimiter and has_sep do
      raise Exceptions.InvalidInputException,
        message: "read_csv takes either 'delimiter' or 'sep', not both"
    end

    :ok
  end

  defp build_table_function_sql(function_name, path_or_paths, opts, option_map) do
    file_expr = encode_table_function_value(path_or_paths)

    options_sql =
      opts
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.map_join(", ", fn {key, value} ->
        mapped_key = Map.get(option_map, key, key)
        "#{mapped_key}=#{encode_table_function_value(value)}"
      end)
      |> case do
        "" -> ""
        options -> ", " <> options
      end

    "SELECT * FROM #{function_name}(#{file_expr}#{options_sql})"
  end

  defp encode_table_function_value(value) when is_map(value) do
    entries =
      value
      |> Enum.map_join(", ", fn {key, entry_value} ->
        "#{Parameters.encode(to_string(key))}: #{encode_table_function_value(entry_value)}"
      end)

    "{#{entries}}"
  end

  defp encode_table_function_value(value) when is_list(value) do
    entries = Enum.map_join(value, ", ", &encode_table_function_value/1)

    "[#{entries}]"
  end

  defp encode_table_function_value(value) do
    Parameters.encode(value)
  end

  defp parse_statements(sql) do
    sql
    |> split_statements()
    |> Enum.reduce_while({:ok, []}, fn statement, {:ok, acc} ->
      case build_statement(statement) do
        {:ok, stmt} -> {:cont, {:ok, [stmt | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, statements} -> {:ok, Enum.reverse(statements)}
      error -> error
    end
  end

  defp build_statement(statement) do
    trimmed = String.trim_leading(statement)

    case String.split(trimmed, ~r/\s+/, parts: 2) do
      [first | _] ->
        type = statement_type(first)

        if type == :invalid do
          {:error,
           %Exceptions.ParserException{
             message: "Parser Error: syntax error at or near \"#{first}\""
           }}
        else
          {:ok,
           %Statement{
             query: statement,
             type: type,
             named_parameters: named_parameters(statement),
             expected_result_type: expected_result_type(type)
           }}
        end

      _ ->
        {:error, %Exceptions.ParserException{message: "Parser Error: empty statement"}}
    end
  end

  @statement_type_map %{
    "SELECT" => StatementType.select(),
    "WITH" => StatementType.select(),
    "INSERT" => StatementType.insert(),
    "UPDATE" => StatementType.update(),
    "DELETE" => StatementType.delete(),
    "CREATE" => StatementType.other(),
    "DROP" => StatementType.other(),
    "ALTER" => StatementType.other(),
    "PRAGMA" => StatementType.other(),
    "BEGIN" => StatementType.other(),
    "COMMIT" => StatementType.other(),
    "ROLLBACK" => StatementType.other(),
    "CHECKPOINT" => StatementType.other(),
    "EXPORT" => StatementType.other(),
    "IMPORT" => StatementType.other(),
    "COPY" => StatementType.other(),
    "SET" => StatementType.other(),
    "RESET" => StatementType.other()
  }

  defp statement_type(word) do
    word
    |> String.upcase()
    |> then(&Map.get(@statement_type_map, &1, :invalid))
  end

  defp expected_result_type(type) do
    case type do
      :select -> [ExpectedResultType.query_result()]
      :insert -> [ExpectedResultType.changed_rows(), ExpectedResultType.query_result()]
      :update -> [ExpectedResultType.changed_rows()]
      :delete -> [ExpectedResultType.changed_rows()]
      _ -> [ExpectedResultType.nothing()]
    end
  end

  defp named_parameters(statement) do
    dollar =
      Regex.scan(~r/\$([0-9]+)/, statement)
      |> Enum.map(fn [_, name] -> name end)

    colon =
      Regex.scan(~r/(?<!:):([a-zA-Z_]\w*)/, statement)
      |> Enum.map(fn [_, name] -> name end)

    MapSet.new(dollar ++ colon)
  end

  defp split_statements(sql) do
    do_split_statements(sql, [], [], false, false)
    |> Enum.reverse()
    |> Enum.filter(fn statement -> String.trim(statement) != "" end)
  end

  defp do_split_statements(<<>>, acc, current, _in_single, _in_double) do
    statement = IO.iodata_to_binary(Enum.reverse(current))
    [statement | acc]
  end

  defp do_split_statements(<<";", rest::binary>>, acc, current, false, false) do
    statement = IO.iodata_to_binary(Enum.reverse(current))
    do_split_statements(rest, [statement | acc], [], false, false)
  end

  defp do_split_statements(<<"'", rest::binary>>, acc, current, false, in_double) do
    case rest do
      <<"'", tail::binary>> ->
        do_split_statements(tail, acc, ["''" | current], false, in_double)

      _ ->
        do_split_statements(rest, acc, ["'" | current], true, in_double)
    end
  end

  defp do_split_statements(<<"'", rest::binary>>, acc, current, true, in_double) do
    case rest do
      <<"'", tail::binary>> ->
        do_split_statements(tail, acc, ["''" | current], true, in_double)

      _ ->
        do_split_statements(rest, acc, ["'" | current], false, in_double)
    end
  end

  defp do_split_statements(<<"\"", rest::binary>>, acc, current, in_single, false) do
    case rest do
      <<"\"", tail::binary>> ->
        do_split_statements(tail, acc, ["\"\"" | current], in_single, false)

      _ ->
        do_split_statements(rest, acc, ["\"" | current], in_single, true)
    end
  end

  defp do_split_statements(<<"\"", rest::binary>>, acc, current, in_single, true) do
    case rest do
      <<"\"", tail::binary>> ->
        do_split_statements(tail, acc, ["\"\"" | current], in_single, true)

      _ ->
        do_split_statements(rest, acc, ["\"" | current], in_single, false)
    end
  end

  defp do_split_statements(<<char::utf8, rest::binary>>, acc, current, in_single, in_double) do
    do_split_statements(rest, acc, [<<char::utf8>> | current], in_single, in_double)
  end

  defp build_values_rows(values) when values in [nil, []] do
    {:error,
     %Exceptions.InvalidInputException{
       message: "Could not create a ValueRelation without any inputs"
     }}
  end

  defp build_values_rows(values) when is_list(values) do
    if Enum.any?(values, fn entry -> is_list(entry) or is_tuple(entry) end) do
      build_values_from_rows(values)
    else
      build_values_from_row(values)
    end
  end

  defp build_values_rows(values) when is_tuple(values) do
    build_values_from_row(Tuple.to_list(values), true)
  end

  defp build_values_rows(value) do
    build_values_from_row([value])
  end

  defp build_values_from_rows(rows) do
    if Enum.all?(rows, fn entry -> is_list(entry) or is_tuple(entry) end) do
      normalized =
        Enum.map(rows, fn entry ->
          case normalize_row(entry) do
            {:ok, row} -> row
            {:error, _} = error -> error
          end
        end)

      case Enum.find(normalized, &match?({:error, _}, &1)) do
        nil ->
          rows = Enum.map(normalized, & &1)
          ensure_uniform_row_lengths!(rows)
          rows_sql = Enum.map_join(rows, ", ", &row_to_sql/1)
          {:ok, rows_sql}

        {:error, exception} ->
          {:error, exception}
      end
    else
      {:error, %Exceptions.InvalidInputException{message: "Expected objects of type tuple"}}
    end
  end

  defp build_values_from_row(values, from_tuple \\ false)

  defp build_values_from_row([], true) do
    {:error, %Exceptions.InvalidInputException{message: "Please provide a non-empty tuple"}}
  end

  defp build_values_from_row(values, _from_tuple) when is_list(values) do
    rows_sql = row_to_sql(values)
    {:ok, rows_sql}
  end

  defp normalize_row(row) when is_tuple(row) do
    list = Tuple.to_list(row)

    if list == [] do
      {:error, %Exceptions.InvalidInputException{message: "Please provide a non-empty tuple"}}
    else
      {:ok, list}
    end
  end

  defp normalize_row(row) when is_list(row) do
    if row == [] do
      {:error, %Exceptions.InvalidInputException{message: "Please provide a non-empty tuple"}}
    else
      {:ok, row}
    end
  end

  defp ensure_uniform_row_lengths!(rows) do
    [first | rest] = rows
    expected = length(first)

    if expected == 0 do
      raise Exceptions.InvalidInputException, message: "Please provide a non-empty tuple"
    end

    Enum.each(rest, fn row ->
      if length(row) != expected do
        raise Exceptions.InvalidInputException,
          message:
            "Mismatch between length of tuples in input, expected #{expected} but found #{length(row)}"
      end
    end)
  end

  defp row_to_sql(values) when is_list(values) do
    values
    |> Enum.map_join(", ", &encode_value/1)
    |> then(&"(#{&1})")
  end

  defp encode_value(value) do
    if valid_value?(value) do
      Parameters.encode(value)
    else
      raise Exceptions.InvalidInputException,
        message: "Please provide arguments of type Expression!"
    end
  end

  defp valid_value?(value) when is_nil(value), do: true
  defp valid_value?(value) when is_binary(value), do: true
  defp valid_value?(value) when is_integer(value), do: true
  defp valid_value?(value) when is_float(value), do: true
  defp valid_value?(value) when is_boolean(value), do: true
  defp valid_value?(%Decimal{}), do: true
  defp valid_value?(%Date{}), do: true
  defp valid_value?(%Time{}), do: true
  defp valid_value?(%NaiveDateTime{}), do: true
  defp valid_value?(%DateTime{}), do: true
  defp valid_value?(value) when is_list(value), do: true
  defp valid_value?(_value), do: false

  @doc """
  Closes the database connection.

  After closing, the connection should not be used for any operations.

  ## Parameters

  - `conn` - The connection to close

  ## Returns

  - `:ok`

  ## Examples

      {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      :ok = DuckdbEx.Connection.close(conn)

  Reference: DuckDBPyConnection.close() in Python
  """
  @spec close(t()) :: :ok
  def close(%Cursor{}), do: :ok
  def close(conn), do: Port.stop(unwrap_conn(conn))
end
