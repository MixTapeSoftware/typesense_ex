defmodule TypesenseEx.NodePoolTest do
  use ExUnit.Case, async: true

  alias TypesenseEx.Node
  alias TypesenseEx.NodeSupervisor
  alias TypesenseEx.NodePool

  describe "without a nearest node" do
    setup do
      nodes_configs = %{
        nodes: [
          %{host: "localhost", port: "8109", protocol: "http"},
          %{host: "localhost", port: "8108", protocol: "http"}
        ]
      }

      pid = start_link_supervised!({NodeSupervisor, nodes_configs})
      %{supervisor_pid: pid}
    end

    test "start_link/1", ctx do
      assert Process.alive?(ctx.supervisor_pid)
    end

    test "next_node/0" do
      assert {1,
              %Node{
                host: "localhost",
                port: "8109",
                protocol: "http",
                last_used: last_used,
                marked_unhealthy_at: nil
              }} = NodePool.next_node()

      assert DateTime.utc_now() |> DateTime.to_date() == last_used |> DateTime.to_date()

      assert {2,
              %TypesenseEx.Node{
                host: "localhost",
                marked_unhealthy_at: nil,
                port: "8108",
                protocol: "http",
                id: nil,
                is_nearest: false,
                last_used: last_used
              }} = NodePool.next_node()

      assert DateTime.utc_now() |> DateTime.to_date() == last_used |> DateTime.to_date()
    end

    test "set_unhealthy/2" do
      {1, %Node{host: "localhost", port: "8109", protocol: "http", marked_unhealthy_at: nil}} =
        NodePool.next_node()

      NodePool.set_unhealthy(1, 10)

      assert {2,
              %Node{host: "localhost", port: "8108", protocol: "http", marked_unhealthy_at: nil}} =
               NodePool.next_node()

      NodePool.set_unhealthy(2, 10)

      assert {nil, nil} = NodePool.next_node()
    end
  end

  describe "with a nearest node" do
    setup do
      nodes_configs = %{
        nearest_node: %{host: "localhost", port: "8108", protocol: "http"},
        nodes: [
          %{host: "localhost", port: "8109", protocol: "http"},
          %{host: "localhost", port: "8108", protocol: "http"}
        ]
      }

      pid = start_link_supervised!({NodeSupervisor, nodes_configs})
      %{supervisor_pid: pid}
    end

    test "start_link/1", ctx do
      assert Process.alive?(ctx.supervisor_pid)
    end

    test "next_node/0" do
      assert {:nearest_node,
              %Node{
                host: "localhost",
                port: "8108",
                protocol: "http",
                last_used: last_used,
                marked_unhealthy_at: nil
              }} = NodePool.next_node()

      assert DateTime.utc_now() |> DateTime.to_date() == last_used |> DateTime.to_date()

      assert {:nearest_node,
              %TypesenseEx.Node{
                host: "localhost",
                marked_unhealthy_at: nil,
                port: "8108",
                protocol: "http",
                id: nil,
                is_nearest: false,
                last_used: last_used
              }} = NodePool.next_node()

      assert DateTime.utc_now() |> DateTime.to_date() == last_used |> DateTime.to_date()
    end

    test "set_unhealthy/2" do
      {node_id, _node} = NodePool.next_node()

      NodePool.set_unhealthy(node_id, 10)

      assert {2,
              %Node{host: "localhost", port: "8109", protocol: "http", marked_unhealthy_at: nil}} =
               NodePool.next_node()

      NodePool.set_unhealthy(2, 10)

      assert {nil, nil} = NodePool.next_node()
    end
  end

  describe "with a nearest node and no nodes" do
    setup do
      nodes_configs = %{
        nearest_node: %{host: "localhost", port: "8108", protocol: "http"},
        nodes: []
      }

      pid = start_link_supervised!({NodeSupervisor, nodes_configs})
      %{supervisor_pid: pid}
    end

    test "start_link/1", ctx do
      assert Process.alive?(ctx.supervisor_pid)
    end

    test "next_node/0" do
      assert {:nearest_node,
              %Node{
                host: "localhost",
                port: "8108",
                protocol: "http",
                last_used: last_used,
                marked_unhealthy_at: nil
              }} = NodePool.next_node()

      assert DateTime.utc_now() |> DateTime.to_date() == last_used |> DateTime.to_date()

      assert {:nearest_node,
              %TypesenseEx.Node{
                host: "localhost",
                marked_unhealthy_at: nil,
                port: "8108",
                protocol: "http",
                id: nil,
                is_nearest: false,
                last_used: last_used
              }} = NodePool.next_node()

      assert DateTime.utc_now() |> DateTime.to_date() == last_used |> DateTime.to_date()
    end

    test "set_unhealthy/2" do
      {node_id, _node} = NodePool.next_node()

      NodePool.set_unhealthy(node_id, 10)

      assert {nil, nil} = NodePool.next_node()
    end
  end
end
