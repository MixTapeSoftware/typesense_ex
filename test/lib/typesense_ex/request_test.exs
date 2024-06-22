defmodule TypesenseEx.RequestTest do
  use TypesenseExCase

  alias TypesenseEx.NodePool
  alias TypesenseEx.Node
  alias TypesenseEx.NodeStore
  alias TypesenseEx.Request

  describe "with valid responses" do
    setup do
      node_configs = %{
        nodes: [
          %{host: "localhost", port: 8109, protocol: "http"},
          %{host: "localhost", port: 8108, protocol: "http"}
        ]
      }

      start_supervised!({Request, node_configs})
      start_supervised!({NodePool, node_configs})

      :ok
    end

    test "requests and handles a valid response" do
      Tesla
      |> expect(:request, fn _client, _options ->
        {:ok, %Tesla.Env{status: 200, body: "{\"results\": []}"}}
      end)

      assert {:ok, %{"results" => []}} == Request.execute(:get, "/fake-endpoint")
    end

    test "request handles jsonl responses" do
      Tesla
      |> expect(:request, 1, fn _client, _options ->
        {:ok, %Tesla.Env{status: 200, body: "{\"success\":true}\n{\"success\":true}"}}
      end)

      assert {:ok, [%{"success" => true}, %{"success" => true}]} =
               Request.execute(:get, "/fake-endpoint")
    end

    test "request encodes in text/plain when given a string body" do
      Tesla
      |> expect(:request, 1, fn _client, args = _rest ->
        headers = Keyword.get(args, :headers)
        assert {"Content-Type", "text/plain"} in headers
        {:ok, %Tesla.Env{status: 200, body: "{}"}}
      end)

      assert {:ok, %{}} = Request.execute(:get, "/fake-endpoint", "string body")
    end
  end

  describe "with invalid responses" do
    setup do
      node_configs = %{
        healthcheck_interval: 5,
        retry_interval: 1,
        nodes: [
          %{host: "localhost", port: 8109, protocol: "http"},
          %{host: "localhost", port: 8108, protocol: "http"}
        ]
      }

      start_supervised!({Request, node_configs})
      start_supervised!({NodePool, node_configs})

      :ok
    end

    test "execute/5 retries, marks nodes healthy/unhealthy if they fail" do
      non_200_resp = %Tesla.Env{status: 500, body: "{\"error\": true}"}

      Tesla
      |> expect(:request, 4, fn _client, _options ->
        {:ok, non_200_resp}
      end)

      assert {:error, ^non_200_resp} = Request.execute(:get, "/fake-endpoint")

      # Node one has been taken out of the rotation
      assert %NodeStore.Node{id: 0, node: %Node{port: 8109}} = NodePool.next_node()
      assert %NodeStore.Node{id: 0, node: %Node{port: 8109}} = NodePool.next_node()

      Process.sleep(10)

      # After our healthcheck_interval, node 1 returns
      assert %NodeStore.Node{id: 1, node: %Node{port: 8108}} = NodePool.next_node()
    end
  end
end
