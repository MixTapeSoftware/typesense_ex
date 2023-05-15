defmodule Typesense.Request do
  @moduledoc """
  Encapsulates Typesense request logic
  """
  alias Typesense.Client
  alias Typesense.TypesenseNode

  @type method :: atom()
  @type path :: String.t()
  @type body :: String.t()
  @type params :: [Keyword.t()]
  @type retries :: integer()
  @type header :: {String.t(), String.t()}

  @callback execute(method(), path(), body(), params(), retries(), TypesenseNode.t() | nil) ::
              {:ok, map()} | {:error, any()}

  @doc """
  Handles executing requests, retrying and marking nodes as healthy/unhealthy
  based on the results
  """
  def execute(method, path, body \\ "", params \\ [], retries \\ 0, retry_node \\ nil) do
    client = Client.get()

    node =
      if not is_nil(retry_node) do
        retry_node
      else
        Client.next_node()
      end

    headers = to_headers(client)

    response =
      Typesense.Http.execute(
        method: method,
        url: url_for(node, path),
        query: params,
        body: body,
        headers: headers
      )

    case response do
      {:ok, %Tesla.Env{status: status, body: body}} when status in 1..499 ->
        Client.set_healthy(node)
        Jason.decode(body)

      {:ok, bad_response} ->
        retries = retries + 1

        if retries <= client.num_retries do
          miliseconds = client.connection_timeout_seconds * 1000
          Process.sleep(miliseconds)
          execute(method, path, body, params, retries, node)
        else
          Client.set_unhealthy(node)
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
