defmodule TypesenseEx.NodePoolTest do
  use ExUnit.Case, async: true
  use Mimic

  alias TypesenseEx.Node
  alias TypesenseEx.NodePool
  alias TypesenseEx.NodeStore
  alias TypesenseEx.OrderedStore

  describe "without a nearest node" do
    setup do
      nodes_configs = %{
        nodes: [
          %{host: "localhost", port: "8109", protocol: "http"},
          %{host: "localhost", port: "8108", protocol: "http"}
        ]
      }

      pid = start_link_supervised!({NodePool, nodes_configs})
      %{supervisor_pid: pid}
    end

    test "start_link/1", ctx do
      assert Process.alive?(ctx.supervisor_pid)
    end

    test "next_node/0" do
      assert {1,
              %Node{
                host: "localhost",
                port: "8108",
                protocol: "http"
              }} = NodePool.next_node()

      assert {0,
              %Node{
                host: "localhost",
                port: "8109",
                protocol: "http"
              }} = NodePool.next_node()

      assert {1,
              %Node{
                host: "localhost",
                port: "8108",
                protocol: "http"
              }} = NodePool.next_node()
    end

    test "set_unhealthy/2" do
      {1,
       %Node{
         host: "localhost",
         port: "8108",
         protocol: "http"
       }} =
        node = NodePool.next_node()

      NodePool.set_unhealthy(node, 1)

      assert {0,
              %Node{
                host: "localhost",
                port: "8109",
                protocol: "http"
              }} =
               node_two = NodePool.next_node()

      NodePool.set_unhealthy(node_two, 1)

      assert {:error, :missing} = NodePool.next_node()

      Process.sleep(5)

      assert {1,
              %Node{
                host: "localhost",
                port: "8108",
                protocol: "http"
              }} =
               NodePool.next_node()
    end
  end

  describe "with a nearest node" do
    setup do
      nodes_configs = %{
        nearest_node: %{host: "localhost", port: "8110", protocol: "http"},
        nodes: [
          %{host: "localhost", port: "8109", protocol: "http"}
        ]
      }

      pid = start_link_supervised!({NodePool, nodes_configs})
      %{supervisor_pid: pid}
    end

    test "start_link/1", ctx do
      assert Process.alive?(ctx.supervisor_pid)
    end

    test "next_node/0" do
      assert {:nearest_node,
              %Node{
                host: "localhost",
                port: "8110",
                protocol: "http"
              }} = NodePool.next_node()

      assert {:nearest_node,
              %Node{
                host: "localhost",
                port: "8110",
                protocol: "http"
              }} = NodePool.next_node()
    end

    test "set_unhealthy/2" do
      assert {:nearest_node,
              %Node{
                host: "localhost",
                port: "8110",
                protocol: "http"
              }} = nearest_node = NodePool.next_node()

      NodePool.set_unhealthy(nearest_node, 1)

      assert {0,
              %Node{
                host: "localhost",
                port: "8109",
                protocol: "http"
              }} =
               node_8109 =
               NodePool.next_node()

      NodePool.set_unhealthy(node_8109, 5)

      assert {:error, :missing} = NodePool.next_node()

      Process.sleep(10)

      assert {:nearest_node,
              %Node{
                host: "localhost",
                port: "8110",
                protocol: "http"
              }} = NodePool.next_node()

      assert {:nearest_node,
              %Node{
                host: "localhost",
                port: "8110",
                protocol: "http"
              }} = NodePool.next_node()
    end
  end

  describe "with a nearest node and no nodes" do
    setup do
      nodes_configs = %{
        nearest_node: %{host: "localhost", port: "8177", protocol: "http"},
        nodes: []
      }

      pid = start_link_supervised!({NodePool, nodes_configs})
      %{supervisor_pid: pid}
    end

    test "start_link/1", ctx do
      assert Process.alive?(ctx.supervisor_pid)
    end

    test "next_node/0" do
      assert {:nearest_node,
              %Node{
                host: "localhost",
                port: "8177",
                protocol: "http"
              }} = NodePool.next_node()

      assert {:nearest_node,
              %Node{
                host: "localhost",
                port: "8177",
                protocol: "http"
              }} = NodePool.next_node()
    end

    test "set_unhealthy/2" do
      {:nearest_node,
       %Node{
         host: "localhost",
         port: "8177",
         protocol: "http"
       }} =
        node = NodePool.next_node()

      # These tests run in a random order
      # So, we set this to a long timeout
      # so that Process.send_after doesn't
      # pollute another test's ETS table
      # TODO: explore mocking strategies here
      NodePool.set_unhealthy(node, 10)

      assert {:error, :missing} = NodePool.next_node()
    end
  end
end
