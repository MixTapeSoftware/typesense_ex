defmodule TypesenseEx.RequestTest do
  use ExUnit.Case, async: true
  alias TypesenseEx.MockHttp
  alias TypesenseEx.MockNode
  alias TypesenseEx.MockPool
  alias TypesenseEx.MockRequestConfig
  alias TypesenseEx.Node
  alias TypesenseEx.Request
  alias TypesenseEx.RequestConfig

  test "requests and handles a valid response" do
    internal_mocks()

    MockHttp
    |> expect(:request, 1, fn _client, _options ->
      {:ok, %Tesla.Env{status: 200, body: "{\"results\": []}"}}
    end)
    |> expect(:client, 1, fn _middleware ->
      {:ok, %Tesla.Env{status: 200, body: "{\"results\": []}"}}
    end)

    assert %TypesenseEx.Request{
             response: {:ok, %{"results" => []}},
             raw_response:
               {:ok,
                %Tesla.Env{
                  method: nil,
                  url: "",
                  query: [],
                  headers: [],
                  body: "{\"results\": []}",
                  status: 200,
                  opts: [],
                  __module__: nil,
                  __client__: nil
                }},
             request_config: %TypesenseEx.RequestConfig{
               api_key: "sdfsdf",
               connection_timeout_seconds: 4,
               healthcheck_interval_seconds: 15,
               num_retries: 3,
               retry_interval_seconds: 0.1
             },
             request_params: %TypesenseEx.RequestParams{
               method: :get,
               url: "https://example.com:1122/fake-endpoint",
               query: [],
               body: "{}",
               headers: [{"X-TYPESENSE-API-KEY", "sdfsdf"}, {"Content-Type", "application/json"}]
             }
           } =
             Request.new()
             |> Request.execute(:get, "/fake-endpoint")
             |> Request.handle_response()
  end

  test "request handles jsonl responses" do
    internal_mocks()

    MockHttp
    |> expect(:request, 1, fn _client, _options ->
      {:ok, %Tesla.Env{status: 200, body: "{\"success\":true}\n{\"success\":true}"}}
    end)
    |> expect(:client, 1, fn _middleware ->
      {:ok, %Tesla.Env{status: 200, body: "{\"results\": []}"}}
    end)

    assert %TypesenseEx.Request{
             raw_response:
               {:ok,
                %Tesla.Env{
                  method: nil,
                  url: "",
                  query: [],
                  headers: [],
                  body: "{\"success\":true}\n{\"success\":true}",
                  status: 200,
                  opts: [],
                  __module__: nil,
                  __client__: nil
                }},
             response: {:ok, [%{"success" => true}, %{"success" => true}]}
           } =
             Request.new()
             |> Request.execute(:get, "/fake-endpoint")
             |> Request.handle_response()
  end

  test "request encodes in text/plain when given a string body" do
    internal_mocks()

    MockHttp
    |> expect(:request, 1, fn _client, %{headers: headers} ->
      assert {"Content-Type", "text/plain"} in headers
      {:ok, %Tesla.Env{status: 500, body: "{}"}}
    end)
    |> expect(:client, 1, fn _middleware ->
      {:ok, %Tesla.Env{status: 200, body: "{\"results\": []}"}}
    end)

    assert %TypesenseEx.Request{
             raw_response:
               {:ok,
                %Tesla.Env{
                  method: nil,
                  url: "",
                  query: [],
                  headers: [],
                  body: "{}",
                  status: 500,
                  opts: [],
                  __module__: nil,
                  __client__: nil
                }},
             request_params: %TypesenseEx.RequestParams{
               method: :get,
               url: "https://example.com:1122/fake-endpoint",
               query: [],
               body: "string body",
               headers: [{"X-TYPESENSE-API-KEY", "sdfsdf"}, {"Content-Type", "text/plain"}]
             },
             response:
               {:maybe_retry,
                %Tesla.Env{
                  method: nil,
                  url: "",
                  query: [],
                  headers: [],
                  body: "{}",
                  status: 500,
                  opts: [],
                  __module__: nil,
                  __client__: nil
                }}
           } =
             Request.new()
             |> Request.execute(:get, "/fake-endpoint", "string body")
             |> Request.handle_response()
  end

  test "request retries, marks nodes unhealthy if they fail" do
    MockPool
    |> expect(:next_node, 1, fn ->
      {:pid_here, %Node{port: 1122, host: "example.com", protocol: "https"}}
    end)

    MockRequestConfig
    |> expect(:get_config, 5, fn ->
      %RequestConfig{
        api_key: "sdfsdf",
        connection_timeout_seconds: 4,
        healthcheck_interval_seconds: 15,
        num_retries: 3,
        retry_interval_seconds: 0.1
      }
    end)

    MockHttp
    |> expect(:request, 4, fn _client, _params ->
      {:ok, %Tesla.Env{status: 500, body: "{}"}}
    end)
    |> expect(:client, 4, fn _middleware -> %Tesla.Client{} end)

    assert %TypesenseEx.Request{response: {:maybe_retry, _request_params}} =
             response =
             Request.new()
             |> Request.execute(:get, "/fake-endpoint")
             |> Request.handle_response()

    MockNode
    |> expect(:set_unhealthy, 1, fn _pid, _seconds -> :ok end)

    assert %{retries: 1} =
             response =
             response
             |> Request.handle_response()
             |> Request.maybe_retry()

    assert %{retries: 2} =
             response =
             response
             |> Request.handle_response()
             |> Request.maybe_retry()

    assert %{retries: 3} =
             response =
             response
             |> Request.handle_response()
             |> Request.maybe_retry()

    assert {:error,
            %Tesla.Env{
              method: nil,
              url: "",
              query: [],
              headers: [],
              body: "{}",
              status: 500,
              opts: [],
              __module__: nil,
              __client__: nil
            }} =
             response
             |> Request.handle_response()
             |> Request.maybe_retry()
  end

  def internal_mocks() do
    MockPool
    |> expect(:next_node, 1, fn ->
      {:pid_here, %Node{port: 1122, host: "example.com", protocol: "https"}}
    end)

    MockRequestConfig
    |> expect(:get_config, 2, fn ->
      %RequestConfig{
        api_key: "sdfsdf",
        connection_timeout_seconds: 4,
        healthcheck_interval_seconds: 15,
        num_retries: 3,
        retry_interval_seconds: 0.1
      }
    end)
  end
end
