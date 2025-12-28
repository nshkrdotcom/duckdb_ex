defmodule DuckdbEx.CLIInstallTest do
  use ExUnit.Case, async: false

  import Mox

  setup :verify_on_exit!

  setup do
    previous = Application.get_env(:duckdb_ex, :http_client)
    Application.put_env(:duckdb_ex, :http_client, DuckdbEx.HTTPClientMock)

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:duckdb_ex, :http_client)
      else
        Application.put_env(:duckdb_ex, :http_client, previous)
      end
    end)

    :ok
  end

  test "resolve_path prefers config then env then installed path" do
    priv_path = DuckdbEx.CLI.installed_path()
    priv_dir = Path.dirname(priv_path)
    project_path = DuckdbEx.CLI.project_priv_path()
    File.rm_rf!(priv_dir)
    File.mkdir_p!(priv_dir)
    File.write!(priv_path, "duckdb")

    on_exit(fn -> File.rm_rf!(priv_dir) end)

    original_config = Application.get_env(:duckdb_ex, :duckdb_path)
    original_env = System.get_env("DUCKDB_PATH")

    on_exit(fn ->
      if is_nil(original_config) do
        Application.delete_env(:duckdb_ex, :duckdb_path)
      else
        Application.put_env(:duckdb_ex, :duckdb_path, original_config)
      end

      if is_nil(original_env) do
        System.delete_env("DUCKDB_PATH")
      else
        System.put_env("DUCKDB_PATH", original_env)
      end
    end)

    Application.put_env(:duckdb_ex, :duckdb_path, "/config/duckdb")
    System.put_env("DUCKDB_PATH", "/env/duckdb")
    assert DuckdbEx.CLI.resolve_path() == "/config/duckdb"

    Application.delete_env(:duckdb_ex, :duckdb_path)
    assert DuckdbEx.CLI.resolve_path() == "/env/duckdb"

    System.delete_env("DUCKDB_PATH")

    if is_binary(project_path) and File.exists?(project_path) do
      assert DuckdbEx.CLI.resolve_path() == project_path
    else
      assert DuckdbEx.CLI.resolve_path() == priv_path
    end
  end

  test "download_url builds platform-specific URLs" do
    assert {:ok, url} = DuckdbEx.CLI.download_url("1.4.3", :linux, :amd64)
    assert url == "https://install.duckdb.org/v1.4.3/duckdb_cli-linux-amd64.gz"

    assert {:ok, url} = DuckdbEx.CLI.download_url("1.4.3", :windows, :arm64)
    assert url == "https://install.duckdb.org/v1.4.3/duckdb_cli-windows-arm64.zip"
  end

  test "install downloads and writes the CLI binary" do
    gz_body = :zlib.gzip("duckdb")

    DuckdbEx.HTTPClientMock
    |> expect(:get, fn "https://install.duckdb.org/v1.4.3/duckdb_cli-linux-amd64.gz" ->
      {:ok, %{status: 200, body: gz_body}}
    end)

    dest_path = DuckdbEx.CLI.installed_path()
    dest_dir = Path.dirname(dest_path)
    File.rm_rf!(dest_dir)

    on_exit(fn -> File.rm_rf!(dest_dir) end)

    assert {:ok, ^dest_path} = DuckdbEx.CLI.install(version: "1.4.3", platform: {:linux, :amd64})
    assert File.read!(dest_path) == "duckdb"
  end
end
