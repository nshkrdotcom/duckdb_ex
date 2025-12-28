defmodule DuckdbEx.DefaultConnection do
  @moduledoc false

  @key {__MODULE__, :default_connection}

  def get do
    case :persistent_term.get(@key, nil) do
      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          {:ok, pid}
        else
          create_and_store()
        end

      _ ->
        create_and_store()
    end
  end

  def peek do
    case :persistent_term.get(@key, nil) do
      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          {:ok, pid}
        else
          :error
        end

      _ ->
        :error
    end
  end

  def set(pid) when is_pid(pid) do
    :persistent_term.put(@key, pid)
    :ok
  end

  def clear do
    :persistent_term.erase(@key)
    :ok
  end

  defp create_and_store do
    case DuckdbEx.Connection.connect(:memory) do
      {:ok, pid} ->
        :persistent_term.put(@key, pid)
        {:ok, pid}

      {:error, _} = error ->
        error
    end
  end
end
