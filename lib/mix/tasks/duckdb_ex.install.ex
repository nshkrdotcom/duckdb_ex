defmodule Mix.Tasks.DuckdbEx.Install do
  use Mix.Task

  @shortdoc "Downloads the DuckDB CLI into priv/duckdb/duckdb"

  @moduledoc """
  Downloads and installs the DuckDB CLI into `priv/duckdb/duckdb`.

  ## Usage

      mix duckdb_ex.install
      mix duckdb_ex.install --version 1.4.3
      mix duckdb_ex.install --force

  ## Options

    * `--version` - DuckDB version to install (defaults to latest stable)
    * `--force` - Re-download even if a binary already exists
  """

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _argv, _errors} =
      OptionParser.parse(args,
        switches: [version: :string, force: :boolean],
        aliases: [v: :version]
      )

    version = opts[:version] || System.get_env("DUCKDB_VERSION")

    dest_path = DuckdbEx.CLI.project_priv_path() || DuckdbEx.CLI.installed_path()

    Mix.shell().info("Installing DuckDB CLI into #{dest_path}...")

    case DuckdbEx.CLI.install(version: version, force: opts[:force], dest_path: dest_path) do
      {:ok, path} ->
        Mix.shell().info("DuckDB CLI installed at #{path}")

      {:error, reason} ->
        Mix.raise("Failed to install DuckDB CLI: #{inspect(reason)}")
    end
  end
end
