defmodule Typesense.Request do
  @moduledoc """
  Encapsulates Typesense request logic
  """
  alias Typesense.Client
  alias Typesense.TypesenseNode

  @type method :: atom()
  @type path :: String.t()
  @type body :: map() | String.t()
  @type params :: [Keyword.t()] | []
  @type retries :: integer()
  @type header :: {String.t(), String.t()}
  @type headers :: [header] | []
  @type response :: {:ok, map()} | {:error, any()}

  @callback execute(method(), path(), body(), params(), retries(), TypesenseNode.t() | nil) ::
              response()

  @doc """
  Handles executing requests, retrying and marking nodes as healthy/unhealthy
  based on the results
  """
  def execute(method, path, body \\ %{}, params \\ [], retries \\ 0, retry_node \\ nil) do
    client = Client.get()

    node = next_node(retry_node)

    headers =
      []
      |> apply_content_type(body)
      |> mabye_apply_api_key(client)

    response =
      Typesense.Http.execute(
        method: method,
        url: url_for(node, path),
        query: params,
        body: maybe_json(body),
        headers: headers
      )

    case response do
      {:ok, %Tesla.Env{status: status, body: body}} when status in 1..499 ->
        Client.set_healthy(node)
        maybe_decode(body)

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

  defp maybe_decode(body) do
    case Jason.decode(body) do
      {:ok, result} ->
        {:ok, result}

      {:error, _err} ->
        # If we send text/plain, we'll get back jsonl
        # in some circumstances
        maybe_decode_jsonl(body)
    end
  end

  defp maybe_decode_jsonl(body) do
    results =
      body
      |> String.split("\n")
      |> Enum.reduce([], fn result, acc ->
        case Jason.decode(result) do
          {:ok, json} ->
            [json | acc]

          {:error, _err} ->
            acc
        end
      end)

    if Enum.empty?(results) do
      {:error, "Can't parse body inspect(#{body})"}
    else
      {:ok, results}
    end
  end

  @spec next_node(TypesenseNode.t() | nil) :: TypesenseNode.t()
  defp next_node(nil), do: Client.next_node()

  defp next_node(retry_node), do: retry_node

  @spec maybe_json(map() | String.t()) :: String.t()
  defp maybe_json(body) when is_map(body) do
    Jason.encode!(body)
  end

  defp maybe_json(body), do: body

  @spec url_for(TypesenseNode.t(), path()) :: String.t()
  defp url_for(%{protocol: protocol, host: host, port: port}, path) do
    URI.encode("#{protocol}://#{host}:#{port}#{path}")
  end

  @spec apply_content_type(headers(), body()) :: headers()
  defp apply_content_type(headers, body) when is_map(body) do
    [{"Content-Type", "application/json"} | headers]
  end

  defp apply_content_type(headers, body) when is_binary(body) do
    [{"Content-Type", "text/plain"} | headers]
  end

  defp mabye_apply_api_key(headers, %Client{api_key: nil}), do: headers

  defp mabye_apply_api_key(headers, %Client{api_key: api_key}) do
    [{"X-TYPESENSE-API-KEY", api_key} | headers]
  end
end
