defmodule DuckdbEx.HTTPClient do
  @moduledoc false

  @type response :: %{status: pos_integer(), body: binary()}

  @callback get(String.t()) :: {:ok, response()} | {:error, term()}
end

defmodule DuckdbEx.HTTPClient.Httpc do
  @moduledoc false
  @behaviour DuckdbEx.HTTPClient

  @impl DuckdbEx.HTTPClient
  def get(url) when is_binary(url) do
    :inets.start()
    :ssl.start()

    url_charlist = String.to_charlist(url)

    case :httpc.request(:get, {url_charlist, []}, [autoredirect: true], body_format: :binary) do
      {:ok, {{_version, status, _reason}, _headers, body}} ->
        {:ok, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
