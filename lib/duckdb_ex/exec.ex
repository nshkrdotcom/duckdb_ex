defmodule DuckdbEx.Exec do
  @moduledoc false

  @type exec_opts :: list()
  @type run_opts :: list()

  @spec start() :: {:ok, pid()} | {:error, term()}
  def start do
    :erlang.apply(:exec, :start, [])
  end

  @spec start(exec_opts()) :: {:ok, pid()} | {:error, term()}
  def start(opts) do
    :erlang.apply(:exec, :start, [opts])
  end

  @spec start_link(exec_opts()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    :erlang.apply(:exec, :start_link, [opts])
  end

  @spec run_link(list(), run_opts()) :: {:ok, pid(), integer()} | {:error, term()}
  def run_link(cmd_args, opts) do
    :erlang.apply(:exec, :run_link, [cmd_args, opts])
  end

  @spec send(integer(), iodata()) :: :ok | {:error, term()}
  def send(os_pid, data) do
    :erlang.apply(:exec, :send, [os_pid, data])
  end
end
