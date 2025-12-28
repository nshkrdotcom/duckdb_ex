defmodule DuckdbEx.Port do
  @moduledoc """
  Manages the DuckDB CLI process using erlexec.

  This module provides a simple wrapper around the DuckDB CLI binary,
  managing it as an OS process via erlexec. Communication happens through
  JSON-formatted commands and responses.

  ## Architecture

  Instead of using Rust NIFs, we use the DuckDB CLI in JSON mode to
  communicate with the database:

      Elixir Process <--> erlexec <--> DuckDB CLI (JSON mode)

  This approach is simpler and avoids the complexity of NIF development
  while still providing full DuckDB functionality.
  """

  use GenServer
  require Logger

  alias DuckdbEx.CLI
  alias DuckdbEx.Exec

  @type t :: pid()

  ## Client API

  @doc """
  Starts a DuckDB process.

  ## Options

    * `:database` - Path to database file or `:memory:` (default: `:memory:`)
    * `:read_only` - Open database in read-only mode (default: `false`)

  ## Examples

      {:ok, port} = DuckdbEx.Port.start_link()
      {:ok, port} = DuckdbEx.Port.start_link(database: "/path/to/db.duckdb")
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Executes a SQL query and returns the result.

  ## Examples

      DuckdbEx.Port.execute(port, "SELECT 1 as num, 'hello' as text")
      #=> {:ok, %{columns: ["num", "text"], rows: [{1, "hello"}]}}
  """
  @spec execute(t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(port, sql, opts \\ []) when is_binary(sql) do
    GenServer.call(port, {:execute, sql, opts}, :infinity)
  end

  @spec last_result(t()) :: {:ok, map() | nil}
  def last_result(port) when is_pid(port) do
    GenServer.call(port, :last_result, :infinity)
  end

  @spec last_sql(t()) :: {:ok, String.t() | nil}
  def last_sql(port) when is_pid(port) do
    GenServer.call(port, :last_sql, :infinity)
  end

  @spec clear_last_result(t()) :: :ok
  def clear_last_result(port) when is_pid(port) do
    GenServer.call(port, :clear_last_result, :infinity)
  end

  @spec connection_info(t()) :: map()
  def connection_info(port) when is_pid(port) do
    GenServer.call(port, :connection_info, :infinity)
  end

  @doc """
  Stops the DuckDB process.
  """
  @spec stop(t()) :: :ok
  def stop(port) when is_pid(port) do
    if Process.alive?(port) do
      GenServer.stop(port, :normal)
    else
      :ok
    end
  end

  def stop(_port), do: :ok

  ## Server Callbacks

  @impl true
  def init(opts) do
    # Start erlexec if not already running
    exec_start_opts =
      case System.get_env("DUCKDB_EX_EXEC_AS_ROOT") do
        "1" -> [{:root, true}, {:user, "root"}]
        "true" -> [{:root, true}, {:user, "root"}]
        _ -> []
      end

    case Exec.start(exec_start_opts) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> throw(error)
    end

    database = Keyword.get(opts, :database, ":memory:")
    read_only = Keyword.get(opts, :read_only, false)

    db_path =
      case database do
        :memory -> ":memory:"
        path when is_binary(path) -> path
      end

    # Build DuckDB command
    # Use JSON mode for easier parsing
    cmd_args = build_command_args(db_path, read_only)

    # Start DuckDB CLI process with erlexec
    exec_opts = [
      :stdin,
      :stdout,
      :stderr,
      :monitor
    ]

    case Exec.run_link(cmd_args, exec_opts) do
      {:ok, exec_pid, os_pid} ->
        Logger.debug("Started DuckDB process: exec_pid=#{inspect(exec_pid)}, os_pid=#{os_pid}")

        state = %{
          exec_pid: exec_pid,
          os_pid: os_pid,
          database: db_path,
          read_only: read_only,
          buffer: "",
          error_buffer: "",
          last_result: nil,
          last_sql: nil,
          pending_finalize: nil,
          pending_finalize_ref: nil
        }

        {:ok, state}

      {:error, reason} ->
        {:stop, {:failed_to_start_duckdb, reason}}
    end
  end

  # Completion marker used to detect when DuckDB has finished processing
  @completion_marker "__DUCKDB_COMPLETE__"
  @finalize_delay_ms 5

  @impl true
  def handle_call({:execute, sql, opts}, from, state) do
    # Send SQL to DuckDB process followed by a marker query
    # This ensures we always get output, even for DDL statements
    command = build_command_with_marker(sql)

    case Exec.send(state.os_pid, command) do
      :ok ->
        # Store the caller to respond later when output arrives
        new_state = Map.put(state, :pending_call, {from, sql, opts})

        {:noreply, new_state}

      error ->
        {:reply, {:error, error}, state}
    end
  end

  def handle_call(:last_result, _from, state) do
    {:reply, {:ok, state.last_result}, state}
  end

  def handle_call(:last_sql, _from, state) do
    {:reply, {:ok, state.last_sql}, state}
  end

  def handle_call(:clear_last_result, _from, state) do
    new_state = %{state | last_result: nil, last_sql: nil}
    {:reply, :ok, new_state}
  end

  def handle_call(:connection_info, _from, state) do
    {:reply, %{database: state.database, read_only: state.read_only}, state}
  end

  defp build_command_with_marker(sql) do
    sql = String.trim(sql)
    sql = if String.ends_with?(sql, ";"), do: sql, else: sql <> ";"
    # Add marker query to signal completion
    sql <> "\nSELECT '#{@completion_marker}' as __status__;\n"
  end

  @impl true
  def handle_info({:stdout, os_pid, data}, %{os_pid: os_pid} = state) do
    # Accumulate output
    buffer = state.buffer <> data

    # Look for the completion marker to know when DuckDB is done
    case Map.get(state, :pending_call) do
      {from, sql, opts} ->
        # Check if buffer contains the completion marker
        if String.contains?(buffer, @completion_marker) do
          if state.error_buffer != "" do
            # There was an error - return it
            error = parse_error(state.error_buffer)
            GenServer.reply(from, {:error, error})

            new_state =
              state
              |> Map.put(:buffer, "")
              |> Map.put(:error_buffer, "")
              |> Map.delete(:pending_call)

            {:noreply, new_state}
          else
            # No error yet - parse and strip the marker from the output, then finalize shortly
            result = parse_and_strip_marker(buffer)
            ref = make_ref()
            Process.send_after(self(), {:finalize, ref}, @finalize_delay_ms)

            new_state =
              state
              |> Map.put(:buffer, "")
              |> Map.delete(:pending_call)
              |> Map.put(:pending_finalize, %{from: from, sql: sql, opts: opts, result: result})
              |> Map.put(:pending_finalize_ref, ref)

            {:noreply, new_state}
          end
        else
          # Continue accumulating until we see the marker
          {:noreply, %{state | buffer: buffer}}
        end

      nil ->
        {:noreply, %{state | buffer: buffer}}
    end
  end

  def handle_info({:stderr, os_pid, data}, %{os_pid: os_pid} = state) do
    Logger.error("DuckDB stderr: #{data}")

    # Check if this is a "transaction aborted" error - if so, the marker won't execute
    # We need to reply immediately instead of waiting for the marker
    error_buffer = state.error_buffer <> data

    cond do
      state.pending_finalize != nil ->
        error = parse_error(error_buffer)
        %{from: from} = state.pending_finalize
        GenServer.reply(from, {:error, error})

        if state.pending_finalize_ref != nil do
          Process.cancel_timer(state.pending_finalize_ref)
        end

        new_state =
          state
          |> Map.put(:buffer, "")
          |> Map.put(:error_buffer, "")
          |> Map.put(:pending_finalize, nil)
          |> Map.put(:pending_finalize_ref, nil)

        {:noreply, new_state}

      String.contains?(data, "Current transaction is aborted") ->
        case Map.get(state, :pending_call) do
          {from, _sql, _opts} ->
            # Transaction is aborted - parse and return error immediately
            error = parse_error(error_buffer)
            GenServer.reply(from, {:error, error})

            new_state =
              state
              |> Map.put(:buffer, "")
              |> Map.put(:error_buffer, "")
              |> Map.delete(:pending_call)

            {:noreply, new_state}

          nil ->
            {:noreply, %{state | error_buffer: error_buffer}}
        end

      true ->
        # Normal error - accumulate and wait for completion marker
        {:noreply, %{state | error_buffer: error_buffer}}
    end
  end

  def handle_info({:finalize, ref}, %{pending_finalize_ref: ref} = state) do
    case state.pending_finalize do
      %{from: from, sql: sql, opts: opts, result: result} ->
        if state.error_buffer != "" do
          error = parse_error(state.error_buffer)
          GenServer.reply(from, {:error, error})

          new_state =
            state
            |> Map.put(:error_buffer, "")
            |> Map.put(:pending_finalize, nil)
            |> Map.put(:pending_finalize_ref, nil)

          {:noreply, new_state}
        else
          GenServer.reply(from, {:ok, result})

          capture_result = Keyword.get(opts, :capture_result, true)

          new_state =
            state
            |> Map.put(:pending_finalize, nil)
            |> Map.put(:pending_finalize_ref, nil)

          final_state =
            if capture_result && result != nil do
              %{new_state | last_result: result, last_sql: sql}
            else
              new_state
            end

          {:noreply, final_state}
        end

      nil ->
        {:noreply, %{state | pending_finalize_ref: nil}}
    end
  end

  def handle_info({:finalize, _ref}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, os_pid, :process, exec_pid, reason}, state)
      when os_pid == state.os_pid and exec_pid == state.exec_pid do
    Logger.info("DuckDB process terminated: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  def handle_info(msg, state) do
    Logger.debug("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  ## Private Functions

  defp build_command_args(database, read_only) do
    # Use DuckDB in JSON mode with line-mode output for easier parsing
    # -json flag outputs results as newline-delimited JSON
    # -batch flag runs in batch mode (non-interactive)
    # -init /dev/null prevents loading .duckdbrc
    duckdb_path = CLI.resolve_path()

    args = [duckdb_path, "-json", "-batch", "-init", "/dev/null"]

    args = if read_only, do: args ++ ["-readonly"], else: args
    args = args ++ [database]

    args
  end

  defp parse_and_strip_marker(data) when is_binary(data) do
    data
    |> extract_json_values()
    |> parse_output_values()
  end

  defp parse_output_values([]), do: %{rows: [], row_count: 0, columns: []}

  defp parse_output_values(values) when is_list(values) do
    results =
      values
      |> Enum.reduce([], fn json, acc ->
        case parse_output_line(json) do
          {:ok, result} -> [result | acc]
          :error -> acc
        end
      end)
      |> Enum.reverse()
      |> Enum.reject(&marker_result?/1)

    case List.last(results) do
      nil -> %{rows: [], row_count: 0, columns: []}
      result -> result
    end
  end

  defp parse_output_line(data) when is_binary(data) do
    trimmed = String.trim(data)

    if trimmed == "" do
      :error
    else
      case Jason.decode(trimmed, objects: :ordered_objects) do
        {:ok, %Jason.OrderedObject{} = row} ->
          {:ok, normalize_rows([ordered_object_values(row)])}

        {:ok, rows} when is_list(rows) ->
          normalized_rows =
            case rows do
              [%Jason.OrderedObject{} | _] -> Enum.map(rows, &ordered_object_values/1)
              _ -> rows
            end

          cond do
            normalized_rows == [] ->
              {:ok, normalize_rows([])}

            ordered_row_entries?(normalized_rows) ->
              {:ok, normalize_rows([normalized_rows])}

            true ->
              {:ok, normalize_rows(normalized_rows)}
          end

        {:ok, row} when is_map(row) ->
          {:ok, normalize_rows([row])}

        {:error, reason} ->
          Logger.warning(
            "Failed to parse DuckDB output: #{inspect(reason)}, data: #{inspect(trimmed)}"
          )

          :error

        _ ->
          :error
      end
    end
  end

  defp normalize_rows([]), do: %{rows: [], row_count: 0, columns: []}

  defp normalize_rows([first | _] = rows) do
    cond do
      ordered_row_entries?(first) ->
        columns = Enum.map(first, &elem(&1, 0))
        tuples = Enum.map(rows, &ordered_row_to_tuple/1)
        %{rows: tuples, row_count: length(tuples), columns: columns}

      is_map(first) ->
        columns = Map.keys(first)

        tuples =
          Enum.map(rows, fn row ->
            columns
            |> Enum.map(&Map.get(row, &1))
            |> List.to_tuple()
          end)

        %{rows: tuples, row_count: length(tuples), columns: columns}

      true ->
        %{rows: [], row_count: 0, columns: []}
    end
  end

  defp ordered_row_to_tuple(row) when is_list(row) do
    row
    |> Enum.map(&elem(&1, 1))
    |> List.to_tuple()
  end

  defp ordered_row_entries?(%Jason.OrderedObject{} = row) do
    ordered_row_entries?(ordered_object_values(row))
  end

  defp ordered_row_entries?(row) when is_list(row) do
    Enum.all?(row, fn
      {key, _value} when is_binary(key) -> true
      _ -> false
    end)
  end

  defp ordered_object_values(%Jason.OrderedObject{values: values}), do: values

  defp marker_result?(%{columns: ["__status__"], rows: [{@completion_marker}]}) do
    true
  end

  defp marker_result?(_), do: false

  defp extract_json_values(data) when is_binary(data) do
    {values, _current, _depth, _in_string, _escape} =
      data
      |> String.to_charlist()
      |> Enum.reduce({[], [], 0, false, false}, fn char,
                                                   {values, current, depth, in_string, escape} ->
        cond do
          escape ->
            {values, [char | current], depth, in_string, false}

          in_string ->
            case char do
              ?\\ -> {values, [char | current], depth, true, true}
              ?" -> {values, [char | current], depth, false, false}
              _ -> {values, [char | current], depth, true, false}
            end

          depth == 0 ->
            case char do
              ?{ -> {values, [char], 1, false, false}
              ?[ -> {values, [char], 1, false, false}
              _ -> {values, current, 0, false, false}
            end

          true ->
            case char do
              ?" ->
                {values, [char | current], depth, true, false}

              ?{ ->
                {values, [char | current], depth + 1, false, false}

              ?[ ->
                {values, [char | current], depth + 1, false, false}

              ?} ->
                new_current = [char | current]
                new_depth = depth - 1

                if new_depth == 0 do
                  json = new_current |> Enum.reverse() |> List.to_string()
                  {[json | values], [], 0, false, false}
                else
                  {values, new_current, new_depth, false, false}
                end

              ?] ->
                new_current = [char | current]
                new_depth = depth - 1

                if new_depth == 0 do
                  json = new_current |> Enum.reverse() |> List.to_string()
                  {[json | values], [], 0, false, false}
                else
                  {values, new_current, new_depth, false, false}
                end

              _ ->
                {values, [char | current], depth, false, false}
            end
        end
      end)

    Enum.reverse(values)
  end

  defp parse_error(data) when is_binary(data) do
    trimmed = String.trim(data)
    first_line = trimmed |> String.split("\n", parts: 2) |> List.first()

    cond do
      match = Regex.run(~r/Error: ([^:]+): (.+)/, first_line) ->
        [_, type, message] = match
        error_string = "#{String.trim(type)}:#{String.trim(message)}"
        DuckdbEx.Exceptions.from_error_string(error_string)

      match = Regex.run(~r/^([A-Za-z ]+ Error):\s*(.+)$/, first_line) ->
        [_, type, message] = match
        normalized_type = normalize_cli_error_type(String.trim(type))
        error_string = "#{normalized_type}:#{String.trim(message)}"
        DuckdbEx.Exceptions.from_error_string(error_string)

      true ->
        %DuckdbEx.Exceptions.Error{message: trimmed}
    end
  end

  @cli_error_type_map %{
    "Binder Error" => "BinderException",
    "Catalog Error" => "CatalogException",
    "Connection Error" => "ConnectionException",
    "Constraint Error" => "ConstraintException",
    "Conversion Error" => "ConversionException",
    "Dependency Error" => "DependencyException",
    "Fatal Error" => "FatalException",
    "HTTP Error" => "HTTPException",
    "Internal Error" => "InternalException",
    "Interrupt Error" => "InterruptException",
    "Invalid Input Error" => "InvalidInputException",
    "Invalid Type Error" => "InvalidTypeException",
    "IO Error" => "IOException",
    "Not Implemented Error" => "NotImplementedException",
    "Not implemented Error" => "NotImplementedException",
    "Out Of Memory Error" => "OutOfMemoryException",
    "Out Of Range Error" => "OutOfRangeException",
    "Out of Memory Error" => "OutOfMemoryException",
    "Out of Range Error" => "OutOfRangeException",
    "Parser Error" => "ParserException",
    "Permission Error" => "PermissionException",
    "Sequence Error" => "SequenceException",
    "Serialization Error" => "SerializationException",
    "Syntax Error" => "SyntaxException",
    "Transaction Error" => "TransactionException",
    "Type Mismatch Error" => "TypeMismatchException",
    "Database Error" => "DatabaseError",
    "Operational Error" => "OperationalError",
    "Integrity Error" => "IntegrityError",
    "Programming Error" => "ProgrammingError",
    "Not Supported Error" => "NotSupportedError"
  }

  defp normalize_cli_error_type(type) do
    Map.get(@cli_error_type_map, type, default_cli_error_type(type))
  end

  defp default_cli_error_type(type) do
    type
    |> String.replace(" Error", "Exception")
    |> String.replace(" ", "")
  end
end
