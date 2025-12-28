defmodule DuckdbEx.Result do
  @moduledoc """
  DuckDB query result handling.

  This module provides functionality for fetching and processing query results,
  mirroring the Python DuckDBPyResult class.

  Reference: duckdb-python/src/duckdb_py/include/duckdb_python/pyresult.hpp

  ## Overview

  Results are returned as maps containing:
  - `:rows` - List of row tuples in column order
  - `:row_count` - Number of rows
  - `:columns` - List of column names (when available)

  ## Examples

      {:ok, result} = DuckdbEx.Connection.execute_result(conn, "SELECT 1 as num, 'hello' as text")
      #=> {:ok, %{rows: [{1, "hello"}], row_count: 1, columns: ["num", "text"]}}

      rows = DuckdbEx.Result.fetch_all(result)
      #=> [{1, "hello"}]
  """

  @type row :: tuple() | map()
  @type t :: %{
          rows: list(row()),
          row_count: non_neg_integer(),
          columns: list(String.t()) | nil
        }

  @doc """
  Fetches all rows from a result.

  ## Parameters

  - `result` - The result map from execute/3

  ## Returns

  - List of row tuples

  ## Examples

      {:ok, result} = DuckdbEx.Connection.execute_result(conn, "SELECT 1, 2, 3")
      rows = DuckdbEx.Result.fetch_all(result)

  Reference: DuckDBPyResult.fetchall() in Python
  """
  @spec fetch_all(t()) :: list(tuple())
  def fetch_all(result) do
    to_tuples(result)
  end

  @doc """
  Fetches one row from a result.

  Returns the first row from the result, or nil if no rows.

  ## Parameters

  - `result` - The result map from execute/3

  ## Returns

  - Row tuple or nil

  ## Examples

      {:ok, result} = DuckdbEx.Connection.execute_result(conn, "SELECT 1 as num")
      row = DuckdbEx.Result.fetch_one(result)
      #=> {1}

  Reference: DuckDBPyResult.fetchone() in Python
  """
  @spec fetch_one(t()) :: tuple() | nil
  def fetch_one(result) do
    case to_tuples(result) do
      [first | _] -> first
      _ -> nil
    end
  end

  @doc """
  Fetches multiple rows from a result.

  Returns the first N rows from the result.

  ## Parameters

  - `result` - The result map from execute/3
  - `count` - Number of rows to fetch

  ## Returns

  - List of row tuples (up to `count` rows)

  ## Examples

      {:ok, result} = DuckdbEx.Connection.execute_result(conn, "SELECT * FROM range(10)")
      rows = DuckdbEx.Result.fetch_many(result, 3)
      #=> [{0}, {1}, {2}]

  Reference: DuckDBPyResult.fetchmany() in Python
  """
  @spec fetch_many(t(), non_neg_integer()) :: list(tuple())
  def fetch_many(result, count) when is_integer(count) do
    result
    |> to_tuples()
    |> Enum.take(count)
  end

  def fetch_many(_, _count), do: []

  @doc """
  Returns the number of rows in the result.

  ## Parameters

  - `result` - The result map from execute/3

  ## Returns

  - Number of rows

  ## Examples

      {:ok, result} = DuckdbEx.Connection.execute(conn, "SELECT * FROM range(100)")
      count = DuckdbEx.Result.row_count(result)
      #=> 100
  """
  @spec row_count(t()) :: non_neg_integer()
  def row_count(%{row_count: count}) when is_integer(count) do
    count
  end

  def row_count(%{rows: rows}) when is_list(rows) do
    length(rows)
  end

  def row_count(_), do: 0

  @doc """
  Converts result to a list of tuples (for DB-API compatibility).

  ## Parameters

  - `result` - The result map from execute/3

  ## Returns

  - List of tuples (row values in order)

  ## Examples

      {:ok, result} = DuckdbEx.Connection.execute_result(conn, "SELECT 1, 'hello'")
      tuples = DuckdbEx.Result.to_tuples(result)
      #=> [{1, "hello"}]
  """
  @spec to_tuples(t()) :: list(tuple())
  def to_tuples(%{rows: rows} = result) when is_list(rows) do
    cond do
      rows == [] ->
        []

      is_tuple(hd(rows)) ->
        rows

      true ->
        columns = columns(%{rows: rows, columns: Map.get(result, :columns, [])}) || []

        Enum.map(rows, fn row when is_map(row) ->
          columns
          |> Enum.map(&Map.get(row, &1))
          |> List.to_tuple()
        end)
    end
  end

  def to_tuples(_), do: []

  @doc """
  Gets column names from the result.

  ## Parameters

  - `result` - The result map from execute/3

  ## Returns

  - List of column names, or nil if not available

  ## Examples

      {:ok, result} = DuckdbEx.Connection.execute(conn, "SELECT 1 as num, 'hello' as text")
      columns = DuckdbEx.Result.columns(result)
      #=> ["num", "text"] or nil
  """
  @spec columns(map()) :: list(String.t()) | nil
  def columns(%{columns: cols}) when is_list(cols) and cols != [] do
    cols
  end

  def columns(%{rows: [first | _]}) when is_map(first) do
    first
    |> Map.keys()
    |> Enum.map(&to_string/1)
  end

  def columns(_), do: nil
end
