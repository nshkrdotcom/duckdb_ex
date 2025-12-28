defmodule DuckdbEx.StatementType do
  @moduledoc """
  Statement type identifiers aligned with DuckDB's Python API.
  """

  @type t :: :select | :insert | :update | :delete | :other

  def select, do: :select
  def insert, do: :insert
  def update, do: :update
  def delete, do: :delete
  def other, do: :other
end
