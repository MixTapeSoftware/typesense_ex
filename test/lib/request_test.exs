defmodule Typesense.RequestTest do
  use ExUnit.Case, async: true
  use ExUnit.CaseTemplate
  alias Typesense.Client
  alias Typesense.Request
  alias Typesense.MockHttp

  import Mox

  @valid_nodes [
    %{host: "localhost", port: "8107", protocol: "https"},
    %{host: "localhost", port: "8108", protocol: "https"}
  ]

  @minimal_valid_config %{
    api_key: "123",
    connection_timeout_seconds: 0,
    num_retries: 2,
    nodes: @valid_nodes,
    # A convenience to prevent tests from being slow
    healthcheck_interval_seconds: 0
  }

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  test "request/5 returns and decodes a valid response" do
    {:ok, _pid} = Client.start_link(@minimal_valid_config)

    MockHttp
    |> expect(:request, 1, fn _client, _options ->
      {:ok, %Tesla.Env{status: 200, body: "{\"results\": []}"}}
    end)
    |> expect(:client, 1, fn _middleware ->
      {:ok, %Tesla.Env{status: 200, body: "{\"results\": []}"}}
    end)

    assert Request.execute(:get, "/fake-endpoint") == {:ok, %{"results" => []}}
  end

  @first_node_params [
    method: :get,
    url: "https://localhost:8107/fake-endpoint",
    query: [],
    body: "",
    headers: [
      {"X-TYPESENSE-API-KEY", "123"},
      {"Content-Type", "application/json"}
    ]
  ]

  test "request/5 retries, marks nodes healthy/unhealthy if they fail/succeed" do
    {:ok, _pid} = Client.start_link(@minimal_valid_config)

    MockHttp
    |> expect(:request, 3, fn _client, @first_node_params ->
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
