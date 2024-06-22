defmodule TypesenseEx.Request do
  @moduledoc """
  Encapsulates Typesense request logic and holds request configuration state.
  """
  use Drops.Contract
  use GenServer

  alias __MODULE__
  alias TypesenseEx.Http
  alias TypesenseEx.NodePool
  alias TypesenseEx.Store

  @table :typesense_ex_request_table

  defstruct [
    :api_key,
    connection_timeout: 10_000,
    num_retries: 3,
    retry_interval: 100
  ]

  schema do
    %{
      optional(:connection_timeout) => integer(gt?: 0),
      optional(:num_retries) => integer(gt?: 0),
      optional(:retry_interval) => integer(gt?: 0),
      optional(:api_key) => string()
    }
  end

  def start_link(params \\ %{}) do
    case Request.conform(params) do
      {:ok, config} ->
        request = struct(Request, config)
        GenServer.start_link(Request, request, name: Request)

      errors ->
        errors
    end
  end

  @impl true
  def init(request) do
    store_init(request)

    {:ok, []}
  end

  @doc """
  Handles executing requests, retrying and marking nodes as healthy/unhealthy
  based on the results
  """
  def execute(method, path, body \\ %{}, params \\ [], retries \\ 0, retry_node \\ nil) do
    %{connection_timeout: timeout} = config = config()

    node = if not is_nil(retry_node), do: retry_node, else: NodePool.next_node()

    headers =
      []
      |> apply_content_type(body)
      |> maybe_apply_api_key(config)

    response =
      Http.execute(
        [
          method: method,
          url: url_for(node, path),
          query: params,
          body: maybe_json(body),
          headers: headers
        ],
        timeout
      )

    case response do
      {:ok, %Tesla.Env{status: status, body: body}} when status in 1..499 ->
        maybe_decode(body)

      {:ok, bad_response} ->
        retries = retries + 1

        if retries <= config.num_retries do
          Process.sleep(config.retry_interval)
          execute(method, path, body, params, retries, node)
        else
          NodePool.set_unhealthy(node)
          {:error, bad_response}
        end

      error ->
        error
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

  defp maybe_json(body) when is_nil(body), do: nil

  defp maybe_json(body) when is_map(body) do
    Jason.encode!(body)
  end

  defp maybe_json(body), do: body

  defp url_for(node, path) do
    %TypesenseEx.NodeStore.Node{node: %{protocol: protocol, host: host, port: port}} = node
    URI.encode("#{protocol}://#{host}:#{port}#{path}")
  end

  defp apply_content_type(headers, body) when is_map(body) do
    [{"Content-Type", "application/json"} | headers]
  end

  defp apply_content_type(headers, body) when is_binary(body) do
    [{"Content-Type", "text/plain"} | headers]
  end

  defp apply_content_type(headers, body) when is_nil(body) do
    headers
  end

  defp maybe_apply_api_key(headers, %Request{api_key: nil}), do: headers

  defp maybe_apply_api_key(headers, %Request{api_key: api_key}) do
    [{"X-TYPESENSE-API-KEY", api_key} | headers]
  end

  defp config() do
    # This should always match
    {:ok, {:config, config}} = Store.get(@table, :config)
    config
  end

  defp store_init(request) do
    Store.init(@table)
    Store.add(@table, :config, request)
  end
end
