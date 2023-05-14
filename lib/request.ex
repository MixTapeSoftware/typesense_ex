defmodule Typesense.Request do
  alias Typesense.Client
  alias Typesense.TypesenseNode

  @type method :: atom()
  @type path :: String.t()
  @type body :: String.t()
  @type params :: [Keyword.t()]
  @type retries :: integer()
  @type header :: {String.t(), String.t()}

  @callback fetch(method(), path(), body(), params(), retries()) :: {:ok, map()} | {:error, any()}
  def fetch(method, path, body, params, retries \\ 0) do
    client = Client.get()
    node = Client.next_node()
    headers = to_headers(client)

    response =
      Typesense.Http.request(
        method: method,
        url: url_for(node, path),
        query: params,
        body: body,
        headers: headers
      )

    case response do
      {:ok, %Tesla.Env{status: status, body: body}} when status in 1..499 ->
        Jason.decode(body)

      {:ok, bad_response} ->
        retries = retries + 1

        if retries <= client.num_retries do
          miliseconds = client.connection_timeout_seconds * 1000
          Process.sleep(miliseconds)
          fetch(method, path, body, params, retries)
        else
          {:error, bad_response}
        end
    end
  end

  @spec url_for(TypesenseNode.t(), path()) :: String.t()
  defp url_for(%{protocol: protocol, host: host, port: port}, path) do
    URI.encode("#{protocol}://#{host}:#{port}#{path}")
  end

  @spec to_headers(Client.t()) :: [header]
  defp to_headers(%Client{api_key: nil}) do
    [
      {"Content-Type", "application/json"}
    ]
  end

  defp to_headers(%Client{api_key: api_key}) do
    [
      {"X-TYPESENSE-API-KEY", api_key},
      {"Content-Type", "application/json"}
    ]
  end
end
