defmodule DuckdbEx.Cursor do
  @moduledoc """
  Lightweight cursor wrapper for DB-API style access.
  """

  @type t :: %__MODULE__{conn: pid()}

  defstruct [:conn]
end
