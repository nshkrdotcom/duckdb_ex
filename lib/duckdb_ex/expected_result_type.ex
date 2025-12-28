defmodule DuckdbEx.ExpectedResultType do
  @moduledoc """
  Expected result types for statements, aligned with DuckDB's Python API.
  """

  @type t :: :query_result | :changed_rows | :nothing

  def query_result, do: :query_result
  def changed_rows, do: :changed_rows
  def nothing, do: :nothing
end
