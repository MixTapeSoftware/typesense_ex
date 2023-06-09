defmodule Typesense.RequestTest do
  use TypesenseCase, async: false
  use ExUnit.Case, async: true
  alias Typesense.Client
  alias Typesense.MockHttp
  alias Typesense.Request

  setup do
    _pid = start_link_supervised!({Typesense.Client, @minimal_valid_config})

    :ok
  end

  test "request/5 returns and decodes a valid response" do
    MockHttp
    |> expect(:request, 1, fn _client, _options ->
      {:ok, %Tesla.Env{status: 200, body: "{\"results\": []}"}}
    end)
    |> expect(:client, 1, fn _middleware ->
      {:ok, %Tesla.Env{status: 200, body: "{\"results\": []}"}}
    end)

    assert Request.execute(:get, "/fake-endpoint") == {:ok, %{"results" => []}}
  end

  test "request/5 handles jsonl responses" do
    MockHttp
    |> expect(:request, 1, fn _client, _options ->
      {:ok, %Tesla.Env{status: 200, body: "{\"success\":true}\n{\"success\":true}"}}
    end)
    |> expect(:client, 1, fn _middleware ->
      {:ok, %Tesla.Env{status: 200, body: "{\"results\": []}"}}
    end)

    assert Request.execute(:get, "/fake-endpoint") ==
             {:ok, [%{"success" => true}, %{"success" => true}]}
  end

  test "request/5 encodes in text/plain when given a string body" do
    MockHttp
    |> expect(:request, 3, fn _client, params ->
      assert {"Content-Type", "text/plain"} in Keyword.get(params, :headers)
      {:ok, %Tesla.Env{status: 500, body: "{}"}}
    end)
    |> expect(:client, 3, fn _middleware ->
      {:ok, %Tesla.Env{status: 200, body: "{\"results\": []}"}}
    end)

    assert Request.execute(:get, "/fake-endpoint", "string body") ==
             {:error,
              %Tesla.Env{
                __client__: nil,
                __module__: nil,
                body: "{}",
                headers: [],
                method: nil,
                opts: [],
                query: [],
                status: 500,
                url: ""
              }}
  end

  @first_node_params [
    method: :get,
    url: "https://localhost:8107/fake-endpoint",
    query: [],
    body: "{}",
    headers: [
      {"X-TYPESENSE-API-KEY", "123"},
      {"Content-Type", "application/json"}
    ]
  ]

  test "request/5 retries, marks nodes healthy/unhealthy if they fail/succeed" do
    MockHttp
    |> expect(:request, 3, fn _client, _params ->
      {:ok, %Tesla.Env{status: 500, body: "{}"}}
    end)
    |> expect(:client, 3, fn _middleware -> %Tesla.Client{} end)

    assert Request.execute(:get, "/fake-endpoint") ==
             {:error,
              %Tesla.Env{
                __client__: nil,
                __module__: nil,
                body: "{}",
                headers: [],
                method: nil,
                opts: [],
                query: [],
                status: 500,
                url: ""
              }}

    # The failed node is marked unhealthy and then
    # immediately unhealthy since healthcheck_interval_seconds == 0
    assert Client.next_node().port == "8108"
    maybe_recovered_node = Client.next_node()
    assert maybe_recovered_node.port == "8107"
    assert maybe_recovered_node.health_status == :maybe_healthy

    # Skip requesting 8108 so that we can demonstrate a node
    # (8107) becoming healthy again below
    Client.next_node()

    MockHttp
    |> expect(:request, 1, fn _client, @first_node_params ->
      {:ok, %Tesla.Env{status: 200, body: "{}"}}
    end)
    |> expect(:client, 1, fn _middleware -> %Tesla.Client{} end)

    assert Request.execute(:get, "/fake-endpoint") == {:ok, %{}}

    # Skip 8108 again
    Client.next_node()

    # 8107 was requested again since its status was :maybe_healthy
    # and this time it returned a 200 status, so it's status should
    # have been marked :healthy again
    maybe_recovered_node = Client.next_node()
    assert maybe_recovered_node.port == "8107"
    assert maybe_recovered_node.health_status == :healthy
  end
end
