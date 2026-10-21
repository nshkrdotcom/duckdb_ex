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

  test "download_url uses the 2.0 tarball names, Windows included" do
    assert {:ok, url} = DuckdbEx.CLI.download_url("2.0.0", :linux, :amd64)
    assert url == "https://install.duckdb.org/v2.0.0/duckdb-cli-linux-amd64.tar.gz"

    assert {:ok, url} = DuckdbEx.CLI.download_url("v2.0.0", :macos, :arm64)
    assert url == "https://install.duckdb.org/v2.0.0/duckdb-cli-osx-arm64.tar.gz"

    assert {:ok, url} = DuckdbEx.CLI.download_url("2.0.0", :windows, :amd64)
    assert url == "https://install.duckdb.org/v2.0.0/duckdb-cli-windows-amd64.tar.gz"
  end

  test "install unpacks the binary from a 2.0 tarball" do
    body = tarball([{~c"duckdb", "duckdb-2"}])

    DuckdbEx.HTTPClientMock
    |> expect(:get, fn "https://install.duckdb.org/v2.0.0/duckdb-cli-linux-amd64.tar.gz" ->
      {:ok, %{status: 200, body: body}}
    end)

    dest_path = fresh_dest()

    assert {:ok, ^dest_path} = DuckdbEx.CLI.install(version: "2.0.0", platform: {:linux, :amd64})
    assert File.read!(dest_path) == "duckdb-2"
  end

  test "install unpacks duckdb.exe from a Windows 2.0 tarball" do
    body = tarball([{~c"README", "x"}, {~c"duckdb.exe", "duckdb-win"}])

    DuckdbEx.HTTPClientMock
    |> expect(:get, fn _url -> {:ok, %{status: 200, body: body}} end)

    dest_path = fresh_dest()

    assert {:ok, _} =
             DuckdbEx.CLI.install(
               version: "2.0.0",
               platform: {:windows, :amd64},
               dest_path: dest_path
             )

    assert File.read!(dest_path) == "duckdb-win"
  end

  test "install reports a tarball without the binary" do
    body = tarball([{~c"README", "x"}])

    DuckdbEx.HTTPClientMock
    |> expect(:get, fn _url -> {:ok, %{status: 200, body: body}} end)

    fresh_dest()

    assert {:error, :duckdb_binary_not_found} =
             DuckdbEx.CLI.install(version: "2.0.0", platform: {:linux, :amd64})
  end

  @tag :tmp_dir
  test "an existing binary of another version is replaced when a version is requested", %{
    tmp_dir: tmp_dir
  } do
    dest_path = Path.join(tmp_dir, "duckdb")
    fake_cli(dest_path, "v1.5.5 (Variegata) d8cdaa33fd")

    DuckdbEx.HTTPClientMock
    |> expect(:get, fn "https://install.duckdb.org/v1.5.3/duckdb_cli-linux-amd64.gz" ->
      {:ok, %{status: 200, body: :zlib.gzip("#!/bin/sh\necho 'v1.5.3 (Variegata) 0123456789'\n")}}
    end)

    assert {:ok, ^dest_path} =
             DuckdbEx.CLI.install(
               version: "1.5.3",
               platform: {:linux, :amd64},
               dest_path: dest_path
             )

    assert DuckdbEx.CLI.installed_version(dest_path) == "1.5.3"
  end

  @tag :tmp_dir
  test "an existing binary of the requested version is kept without a download", %{
    tmp_dir: tmp_dir
  } do
    dest_path = Path.join(tmp_dir, "duckdb")
    fake_cli(dest_path, "v1.5.3 (Variegata) 0123456789")

    # No expectation: any HTTP call fails verify_on_exit!.
    assert {:ok, ^dest_path} =
             DuckdbEx.CLI.install(
               version: "v1.5.3",
               platform: {:linux, :amd64},
               dest_path: dest_path
             )
  end

  @tag :tmp_dir
  test "without a requested version an existing binary is kept", %{tmp_dir: tmp_dir} do
    dest_path = Path.join(tmp_dir, "duckdb")
    fake_cli(dest_path, "v1.5.5 (Variegata) d8cdaa33fd")

    previous = System.get_env("DUCKDB_VERSION")
    System.delete_env("DUCKDB_VERSION")
    on_exit(fn -> if previous, do: System.put_env("DUCKDB_VERSION", previous) end)

    assert {:ok, ^dest_path} =
             DuckdbEx.CLI.install(platform: {:linux, :amd64}, dest_path: dest_path)
  end

  test "installed_version is nil for a file that cannot run" do
    assert DuckdbEx.CLI.installed_version("/nonexistent/duckdb") == nil
  end

  defp tarball(entries) do
    path =
      Path.join(System.tmp_dir!(), "duckdb_ex_test_#{System.unique_integer([:positive])}.tar.gz")

    :ok = :erl_tar.create(String.to_charlist(path), entries, [:compressed])
    body = File.read!(path)
    File.rm!(path)
    body
  end

  defp fresh_dest do
    dest_path = DuckdbEx.CLI.installed_path()
    dest_dir = Path.dirname(dest_path)
    File.rm_rf!(dest_dir)
    on_exit(fn -> File.rm_rf!(dest_dir) end)
    dest_path
  end

  defp fake_cli(path, version_line) do
    File.write!(path, "#!/bin/sh\necho '#{version_line}'\n")
    File.chmod!(path, 0o755)
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
