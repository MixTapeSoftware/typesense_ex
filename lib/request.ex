defmodule TypesenseEx.Request do
  @moduledoc """
  Encapsulates Typesense request logic
  """

  alias __MODULE__
  alias TypesenseEx.RequestConfig
  alias TypesenseEx.RequestParams
  alias TypesenseEx.Pool
  alias TypesenseEx.Request
  alias TypesenseEx.Node

  @type retries :: integer()
  @type response :: {:ok, map()} | {:error, any()}

  @derive {Inspect, only: [:request_config, :request_params, :response, :raw_response]}

  defstruct [
    :request_config,
    :node,
    retries: 0,
    response: nil,
    raw_response: nil,
    request_params: nil,
    nearest_node: nil
  ]

  def next_node, do: pool_impl().next_node
  def request_config, do: config_impl().get_config
  def set_unhealthy(node_pid, seconds), do: node_impl().set_unhealthy(node_pid, seconds)

  def new do
    struct(Request, %{node: next_node(), request_config: request_config()})
  end

  def execute(%{request_params: params} = request) do
    %{request | raw_response: TypesenseEx.Http.execute(params)}
  end

  def execute(request, method, path, body \\ %{}, query \\ []) do
    %{node: {_pid, node_config}, request_config: %{api_key: api_key}} = request
    params = RequestParams.new(node_config, method, path, body, query, api_key)

    %{request | request_params: params, raw_response: TypesenseEx.Http.execute(params)}
  end

  def handle_response(%{raw_response: raw_response} = request) do
    response =
      case raw_response do
        {:ok, %Tesla.Env{status: status, body: body}} when status in 1..499 ->
          maybe_decode(body)

        {:ok, bad_response} ->
          {:maybe_retry, bad_response}
      end

    %{request | response: response}
  end

  def maybe_retry(%Request{
        response: {:maybe_retry, bad_response},
        request_config: %{
          num_retries: num_retries,
          healthcheck_interval_seconds: retry_in
        },
        node: {node_pid, _config},
        retries: retries
      })
      when retries >= num_retries do
    set_unhealthy(node_pid, retry_in)

    {:error, bad_response}
  end

  def maybe_retry(
        %Request{
          response: {:maybe_retry, _bad_response},
          retries: retries,
          request_config: %{
            retry_interval_seconds: retry_interval_seconds
          }
        } = request
      ) do
    (retry_interval_seconds * 1000) |> round() |> Process.sleep()

    execute(%{request | retries: retries + 1}) |> handle_response()
  end

  def maybe_retry(request), do: request

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

  defp pool_impl do
    Application.get_env(:typesense_ex, :pool, Pool)
  end

  defp node_impl do
    Application.get_env(:typesense_ex, :node, Node)
  end

  defp config_impl do
    Application.get_env(:typesense_ex, :request_config, RequestConfig)
  end
end
