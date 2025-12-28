defmodule DuckdbEx.Parameters do
  @moduledoc false

  alias DuckdbEx.Exceptions

  @spec interpolate(String.t(), nil | list() | tuple() | map()) ::
          {:ok, String.t()} | {:error, term()}
  def interpolate(sql, nil), do: {:ok, sql}
  def interpolate(sql, []), do: {:ok, sql}

  def interpolate(sql, params) when is_tuple(params) do
    interpolate(sql, Tuple.to_list(params))
  end

  def interpolate(sql, params) when is_list(params) do
    cond do
      String.contains?(sql, "?") ->
        replace_qmark(sql, params)

      Regex.match?(~r/\$\d+/, sql) ->
        replace_dollar(sql, params)

      true ->
        {:ok, sql}
    end
  end

  def interpolate(sql, params) when is_map(params) do
    cond do
      String.contains?(sql, "?") ->
        {:error,
         %Exceptions.InvalidInputException{
           message: "named parameters are not supported with qmark placeholders"
         }}

      Regex.match?(~r/\$\d+/, sql) ->
        replace_dollar_named(sql, params)

      Regex.match?(~r/:[a-zA-Z_]\w*/, sql) ->
        replace_named(sql, params)

      true ->
        {:ok, sql}
    end
  end

  defp replace_qmark(sql, params) do
    do_replace_qmark(sql, params, [], false, false)
  end

  defp do_replace_qmark(<<>>, [], acc, _in_single, _in_double) do
    {:ok, IO.iodata_to_binary(Enum.reverse(acc))}
  end

  defp do_replace_qmark(<<>>, _params, _acc, _in_single, _in_double) do
    {:error,
     %Exceptions.InvalidInputException{
       message: "too many parameters supplied for query"
     }}
  end

  defp do_replace_qmark(<<"'", rest::binary>>, params, acc, false, in_double) do
    case rest do
      <<"'", tail::binary>> ->
        do_replace_qmark(tail, params, ["''" | acc], false, in_double)

      _ ->
        do_replace_qmark(rest, params, ["'" | acc], true, in_double)
    end
  end

  defp do_replace_qmark(<<"'", rest::binary>>, params, acc, true, in_double) do
    case rest do
      <<"'", tail::binary>> ->
        do_replace_qmark(tail, params, ["''" | acc], true, in_double)

      _ ->
        do_replace_qmark(rest, params, ["'" | acc], false, in_double)
    end
  end

  defp do_replace_qmark(<<"\"", rest::binary>>, params, acc, in_single, false) do
    case rest do
      <<"\"", tail::binary>> ->
        do_replace_qmark(tail, params, ["\"\"" | acc], in_single, false)

      _ ->
        do_replace_qmark(rest, params, ["\"" | acc], in_single, true)
    end
  end

  defp do_replace_qmark(<<"\"", rest::binary>>, params, acc, in_single, true) do
    case rest do
      <<"\"", tail::binary>> ->
        do_replace_qmark(tail, params, ["\"\"" | acc], in_single, true)

      _ ->
        do_replace_qmark(rest, params, ["\"" | acc], in_single, false)
    end
  end

  defp do_replace_qmark(<<"?", rest::binary>>, [param | tail], acc, false, false) do
    do_replace_qmark(rest, tail, [encode_param(param) | acc], false, false)
  end

  defp do_replace_qmark(<<"?", _rest::binary>>, [], _acc, false, false) do
    {:error,
     %Exceptions.InvalidInputException{
       message: "not enough parameters supplied for query"
     }}
  end

  defp do_replace_qmark(<<char::utf8, rest::binary>>, params, acc, in_single, in_double) do
    do_replace_qmark(rest, params, [<<char::utf8>> | acc], in_single, in_double)
  end

  defp replace_dollar(sql, params) do
    do_replace_dollar(sql, params, [], false, false)
  end

  defp replace_dollar_named(sql, params) do
    do_replace_dollar(sql, params, [], false, false)
  end

  defp do_replace_dollar(<<>>, _params, acc, _in_single, _in_double) do
    {:ok, IO.iodata_to_binary(Enum.reverse(acc))}
  end

  defp do_replace_dollar(<<"'", rest::binary>>, params, acc, false, in_double) do
    case rest do
      <<"'", tail::binary>> ->
        do_replace_dollar(tail, params, ["''" | acc], false, in_double)

      _ ->
        do_replace_dollar(rest, params, ["'" | acc], true, in_double)
    end
  end

  defp do_replace_dollar(<<"'", rest::binary>>, params, acc, true, in_double) do
    case rest do
      <<"'", tail::binary>> ->
        do_replace_dollar(tail, params, ["''" | acc], true, in_double)

      _ ->
        do_replace_dollar(rest, params, ["'" | acc], false, in_double)
    end
  end

  defp do_replace_dollar(<<"\"", rest::binary>>, params, acc, in_single, false) do
    case rest do
      <<"\"", tail::binary>> ->
        do_replace_dollar(tail, params, ["\"\"" | acc], in_single, false)

      _ ->
        do_replace_dollar(rest, params, ["\"" | acc], in_single, true)
    end
  end

  defp do_replace_dollar(<<"\"", rest::binary>>, params, acc, in_single, true) do
    case rest do
      <<"\"", tail::binary>> ->
        do_replace_dollar(tail, params, ["\"\"" | acc], in_single, true)

      _ ->
        do_replace_dollar(rest, params, ["\"" | acc], in_single, false)
    end
  end

  defp do_replace_dollar(<<"$", rest::binary>>, params, acc, false, false) do
    case Integer.parse(rest) do
      {index, tail} ->
        case fetch_param(params, index) do
          {:ok, param} ->
            do_replace_dollar(tail, params, [encode_param(param) | acc], false, false)

          {:error, reason} ->
            {:error, reason}
        end

      :error ->
        do_replace_dollar(rest, params, ["$" | acc], false, false)
    end
  end

  defp do_replace_dollar(<<char::utf8, rest::binary>>, params, acc, in_single, in_double) do
    do_replace_dollar(rest, params, [<<char::utf8>> | acc], in_single, in_double)
  end

  defp replace_named(sql, params) do
    do_replace_named(sql, params, [], false, false)
  end

  defp do_replace_named(<<>>, _params, acc, _in_single, _in_double) do
    {:ok, IO.iodata_to_binary(Enum.reverse(acc))}
  end

  defp do_replace_named(<<"'", rest::binary>>, params, acc, false, in_double) do
    case rest do
      <<"'", tail::binary>> ->
        do_replace_named(tail, params, ["''" | acc], false, in_double)

      _ ->
        do_replace_named(rest, params, ["'" | acc], true, in_double)
    end
  end

  defp do_replace_named(<<"'", rest::binary>>, params, acc, true, in_double) do
    case rest do
      <<"'", tail::binary>> ->
        do_replace_named(tail, params, ["''" | acc], true, in_double)

      _ ->
        do_replace_named(rest, params, ["'" | acc], false, in_double)
    end
  end

  defp do_replace_named(<<"\"", rest::binary>>, params, acc, in_single, false) do
    case rest do
      <<"\"", tail::binary>> ->
        do_replace_named(tail, params, ["\"\"" | acc], in_single, false)

      _ ->
        do_replace_named(rest, params, ["\"" | acc], in_single, true)
    end
  end

  defp do_replace_named(<<"\"", rest::binary>>, params, acc, in_single, true) do
    case rest do
      <<"\"", tail::binary>> ->
        do_replace_named(tail, params, ["\"\"" | acc], in_single, true)

      _ ->
        do_replace_named(rest, params, ["\"" | acc], in_single, false)
    end
  end

  defp do_replace_named(<<"::", rest::binary>>, params, acc, in_single, in_double) do
    do_replace_named(rest, params, ["::" | acc], in_single, in_double)
  end

  defp do_replace_named(<<":", rest::binary>>, params, acc, false, false) do
    case Regex.run(~r/^([a-zA-Z_]\w*)/, rest) do
      [name] ->
        case fetch_param(params, name) do
          {:ok, param} ->
            tail = String.slice(rest, String.length(name)..-1)
            do_replace_named(tail, params, [encode_param(param) | acc], false, false)

          {:error, reason} ->
            {:error, reason}
        end

      _ ->
        do_replace_named(rest, params, [":" | acc], false, false)
    end
  end

  defp do_replace_named(<<char::utf8, rest::binary>>, params, acc, in_single, in_double) do
    do_replace_named(rest, params, [<<char::utf8>> | acc], in_single, in_double)
  end

  defp fetch_param(params, index) when is_list(params) do
    if index <= 0 do
      {:error,
       %Exceptions.InvalidInputException{
         message: "parameter index must be positive"
       }}
    else
      case Enum.fetch(params, index - 1) do
        {:ok, value} ->
          {:ok, value}

        :error ->
          {:error,
           %Exceptions.InvalidInputException{message: "parameter index #{index} out of range"}}
      end
    end
  end

  defp fetch_param(params, key) when is_map(params) do
    key_string = to_string(key)

    case Map.fetch(params, key_string) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        case Enum.find(params, fn {param_key, _value} ->
               is_atom(param_key) and Atom.to_string(param_key) == key_string
             end) do
          {_, value} ->
            {:ok, value}

          nil ->
            {:error,
             %Exceptions.InvalidInputException{message: "missing parameter #{key_string}"}}
        end
    end
  end

  defp encode_param(nil), do: "NULL"
  defp encode_param(true), do: "TRUE"
  defp encode_param(false), do: "FALSE"

  defp encode_param(%Decimal{} = value) do
    Decimal.to_string(value, :normal)
  end

  defp encode_param(%Date{} = value) do
    "'#{Date.to_iso8601(value)}'"
  end

  defp encode_param(%Time{} = value) do
    "'#{Time.to_iso8601(value)}'"
  end

  defp encode_param(%NaiveDateTime{} = value) do
    "'#{NaiveDateTime.to_iso8601(value)}'"
  end

  defp encode_param(%DateTime{} = value) do
    "'#{DateTime.to_iso8601(value)}'"
  end

  defp encode_param(value) when is_integer(value) or is_float(value) do
    to_string(value)
  end

  defp encode_param(value) when is_binary(value) do
    "'" <> escape_string(value) <> "'"
  end

  defp encode_param(value) when is_list(value) do
    encoded = Enum.map_join(value, ", ", &encode_param/1)

    "[" <> encoded <> "]"
  end

  defp encode_param(value) do
    "'" <> escape_string(to_string(value)) <> "'"
  end

  defp escape_string(value) do
    String.replace(value, "'", "''")
  end

  @spec encode(term()) :: String.t()
  def encode(value) do
    encode_param(value)
  end
end
