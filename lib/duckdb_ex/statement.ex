defmodule DuckdbEx.Statement do
  @moduledoc """
  Represents a parsed SQL statement with metadata.
  """

  @enforce_keys [:query, :type, :named_parameters, :expected_result_type]
  defstruct [:query, :type, :named_parameters, :expected_result_type]

  @type t :: %__MODULE__{
          query: String.t(),
          type: DuckdbEx.StatementType.t(),
          named_parameters: MapSet.t(),
          expected_result_type: [DuckdbEx.ExpectedResultType.t()]
        }
end
