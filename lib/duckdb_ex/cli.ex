defmodule DuckdbEx.CLI do
  @moduledoc """
  DuckDB CLI resolution and installer helpers.

  The installer downloads the DuckDB CLI into `priv/duckdb/duckdb` (or
  `priv/duckdb/duckdb.exe` on Windows). Runtime resolution checks:

  1. `config :duckdb_ex, :duckdb_path`
  2. `DUCKDB_PATH`
  3. `priv/duckdb/duckdb` (installed binary)
  4. `duckdb` on PATH
  5. `/usr/local/bin/duckdb` fallback
  """

  alias DuckdbEx.HTTPClient.Httpc

  @type os :: :linux | :macos | :windows
  @type arch :: :amd64 | :arm64
  @type platform :: {os(), arch()}

  @latest_version_url "https://duckdb.org/data/latest_stable_version.txt"
  @install_base_url "https://install.duckdb.org"

  @spec installed_path() :: String.t()
  def installed_path do
    priv_dir = :code.priv_dir(:duckdb_ex) |> to_string()
    Path.join([priv_dir, "duckdb", binary_name()])
  end

  @spec project_priv_path() :: String.t() | nil
  def project_priv_path do
    if Code.ensure_loaded?(Mix) and function_exported?(Mix, :env, 0) do
      Path.join([File.cwd!(), "priv", "duckdb", binary_name()])
    end
  end

  @spec resolve_path() :: String.t()
  def resolve_path do
    config_path = Application.get_env(:duckdb_ex, :duckdb_path)
    env_path = System.get_env("DUCKDB_PATH")
    project_path = project_priv_path()
    priv_path = installed_path()

    cond do
      valid_path?(config_path) -> config_path
      valid_path?(env_path) -> env_path
      is_binary(project_path) and File.exists?(project_path) -> project_path
      File.exists?(priv_path) -> priv_path
      path = System.find_executable("duckdb") -> path
      true -> default_path()
    end
  end

  @spec install(keyword()) :: {:ok, String.t()} | {:error, term()}
  def install(opts \\ []) do
    dest_path = opts[:dest_path] || installed_path()

    if File.exists?(dest_path) and !Keyword.get(opts, :force, false) and
         installed_matches?(dest_path, requested_version(opts)) do
      {:ok, dest_path}
    else
      with {:ok, version} <- resolve_version(opts),
           {:ok, platform} <- resolve_platform(opts),
           {:ok, url} <- download_url(version, elem(platform, 0), elem(platform, 1)),
           {:ok, response} <- http_client().get(url),
           {:ok, body} <- ensure_ok(response),
           :ok <- write_binary(dest_path, body, platform) do
        {:ok, dest_path}
      end
    end
  rescue
    error in ArgumentError ->
      {:error, error.message}
  end

  @spec download_url(String.t(), os(), arch()) :: {:ok, String.t()} | {:error, term()}
  def download_url(version, os, arch) when is_binary(version) do
    normalized = normalize_version(version)

    if tarball_layout?(normalized) do
      with {:ok, dist, _ext} <- distribution(os, arch) do
        {:ok, "#{@install_base_url}/v#{normalized}/duckdb-cli-#{dist}.tar.gz"}
      end
    else
      with {:ok, dist, ext} <- distribution(os, arch) do
        {:ok, "#{@install_base_url}/v#{normalized}/duckdb_cli-#{dist}.#{ext}"}
      end
    end
  end

  @doc """
  The version an installed DuckDB CLI reports through `--version`, or `nil`
  when the file cannot be run or its output carries no version.
  """
  @spec installed_version(String.t()) :: String.t() | nil
  def installed_version(path) do
    {output, 0} = System.cmd(path, ["--version"], stderr_to_stdout: true)

    case Regex.run(~r/v?(\d+\.\d+\.\d+)/, output, capture: :all_but_first) do
      [version] -> version
      _ -> nil
    end
  rescue
    _ -> nil
  catch
    _, _ -> nil
  end

  # DuckDB 2.0 publishes every CLI as `duckdb-cli-<platform>.tar.gz`, Windows
  # included. 1.x used `duckdb_cli-<platform>.gz` (`.zip` on Windows).
  defp tarball_layout?(version) do
    case Integer.parse(version) do
      {major, _rest} -> major >= 2
      :error -> false
    end
  end

  # An existing binary is kept unless an explicit version was asked for and
  # the binary reports a different one. Without this check, a checkout that
  # installed an older or newer CLI kept it indefinitely.
  defp installed_matches?(_dest_path, nil), do: true

  defp installed_matches?(dest_path, version),
    do: installed_version(dest_path) == normalize_version(version)

  defp requested_version(opts) do
    case opts[:version] || System.get_env("DUCKDB_VERSION") do
      version when is_binary(version) and version != "" -> version
      _ -> nil
    end
  end

  @doc false
  @spec platform() :: {:ok, platform()} | {:error, term()}
  def platform do
    with {:ok, os} <- os_type(),
         {:ok, arch} <- arch_type() do
      {:ok, {os, arch}}
    end
  end

  defp resolve_version(opts) do
    version =
      opts[:version] ||
        System.get_env("DUCKDB_VERSION")

    if is_binary(version) and version != "" do
      {:ok, normalize_version(version)}
    else
      fetch_latest_version()
    end
  end

  defp resolve_platform(opts) do
    case opts[:platform] do
      {os, arch} when os in [:linux, :macos, :windows] and arch in [:amd64, :arm64] ->
        {:ok, {os, arch}}

      nil ->
        platform()

      other ->
        {:error, {:invalid_platform, other}}
    end
  end

  defp fetch_latest_version do
    case http_client().get(@latest_version_url) do
      {:ok, response} ->
        ensure_ok(response)
        |> case do
          {:ok, body} -> {:ok, body |> to_string() |> String.trim()}
          {:error, _} = error -> error
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp write_binary(dest_path, body, {os, _arch}) do
    dest_dir = Path.dirname(dest_path)
    File.mkdir_p!(dest_dir)

    if File.exists?(dest_path) do
      File.rm!(dest_path)
    end

    with {:ok, binary} <- extract_binary(body, os),
         :ok <- File.write(dest_path, binary) do
      ensure_executable(dest_path, os)
    end
  end

  # A 2.0+ tarball (every platform), recognised by its content: a gzip
  # stream whose payload is a tar archive. 1.x `.gz` assets are a bare
  # gzipped binary and fall through to the clauses below.
  defp extract_binary(body, os) do
    case :erl_tar.extract({:binary, body}, [:compressed, :memory]) do
      {:ok, [_ | _] = entries} -> find_entry(entries, os)
      _ -> extract_legacy(body, os)
    end
  end

  defp find_entry(entries, os) do
    name = if os == :windows, do: "duckdb.exe", else: "duckdb"

    case Enum.find(entries, fn {entry, _} -> Path.basename(to_string(entry)) == name end) do
      {_, binary} -> {:ok, binary}
      nil -> {:error, :duckdb_binary_not_found}
    end
  end

  defp extract_legacy(body, :windows) do
    case :zip.extract(body, [:memory]) do
      {:ok, entries} ->
        case Enum.find(entries, fn {name, _} ->
               String.ends_with?(to_string(name), "duckdb.exe")
             end) do
          {_, binary} -> {:ok, binary}
          nil -> {:error, :duckdb_binary_not_found}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_legacy(body, _os) do
    {:ok, :zlib.gunzip(body)}
  end

  defp ensure_executable(path, os) do
    case os do
      :windows -> :ok
      _ -> File.chmod(path, 0o755)
    end
  end

  defp distribution(:linux, :amd64), do: {:ok, "linux-amd64", "gz"}
  defp distribution(:linux, :arm64), do: {:ok, "linux-arm64", "gz"}
  defp distribution(:macos, :amd64), do: {:ok, "osx-amd64", "gz"}
  defp distribution(:macos, :arm64), do: {:ok, "osx-arm64", "gz"}
  defp distribution(:windows, :amd64), do: {:ok, "windows-amd64", "zip"}
  defp distribution(:windows, :arm64), do: {:ok, "windows-arm64", "zip"}
  defp distribution(os, arch), do: {:error, {:unsupported_platform, {os, arch}}}

  defp os_type do
    case :os.type() do
      {:unix, :linux} -> {:ok, :linux}
      {:unix, :darwin} -> {:ok, :macos}
      {:win32, :nt} -> {:ok, :windows}
      other -> {:error, {:unsupported_os, other}}
    end
  end

  defp arch_type do
    arch =
      :erlang.system_info(:system_architecture)
      |> to_string()

    cond do
      String.contains?(arch, "x86_64") or String.contains?(arch, "amd64") -> {:ok, :amd64}
      String.contains?(arch, "aarch64") or String.contains?(arch, "arm64") -> {:ok, :arm64}
      true -> {:error, {:unsupported_arch, arch}}
    end
  end

  defp binary_name do
    case os_type() do
      {:ok, :windows} -> "duckdb.exe"
      _ -> "duckdb"
    end
  end

  defp default_path do
    case os_type() do
      {:ok, :windows} -> "duckdb.exe"
      _ -> "/usr/local/bin/duckdb"
    end
  end

  defp valid_path?(path), do: is_binary(path) and path != ""

  defp normalize_version("v" <> version), do: version
  defp normalize_version(version), do: version

  defp ensure_ok(%{status: 200, body: body}), do: {:ok, body}
  defp ensure_ok(%{status: status}), do: {:error, {:http_error, status}}

  defp http_client do
    Application.get_env(:duckdb_ex, :http_client, Httpc)
  end
end
