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
    nodes: @valid_nodes,
    connection_timeout_seconds: 0,
    num_retries: 2
  }

  defmodule Typesense.SuccessClient do
    def request(
          method: :get,
          url: "https://localhost:8107/fake-endpoint",
          query: [],
          body: "",
          headers: [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "application/json"}]
        ) do
      {:ok, %Tesla.Env{status: 200, body: "{\"results\": []}"}}
    end
  end

  defmodule Typesense.FailClient do
    def request(
          method: :get,
          url: "https://localhost:8107/fake-endpoint",
          query: [],
          body: "",
          headers: [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "application/json"}]
        ) do
      {:ok, %Tesla.Env{status: 500, body: "{}"}}
    end

    def request(
          method: :get,
          url: "https://localhost:8108/fake-endpoint",
          query: [],
          body: "",
          headers: [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "application/json"}]
        ) do
      {:ok, %Tesla.Env{status: 500, body: "{}"}}
    end
  end

  # # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  test "request/5 returns and decodes a valid response" do
    {:ok, _pid} = Client.start_link(@minimal_valid_config)

    MockHttp
    |> expect(:client, 1, fn _middleware, _adapter -> Typesense.SuccessClient end)

    assert Request.fetch(:get, "/fake-endpoint", "", []) == {:ok, %{"results" => []}}
  end

  test "request/5 retries twice after a bad response" do
    {:ok, _pid} = Client.start_link(@minimal_valid_config)

    MockHttp
    |> expect(:client, 3, fn _middleware, _adapter -> Typesense.FailClient end)

    assert Request.fetch(:get, "/fake-endpoint", "", []) ==
             {:error,
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
  end
end
