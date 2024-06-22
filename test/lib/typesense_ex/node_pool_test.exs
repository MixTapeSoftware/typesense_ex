defmodule TypesenseEx.NodePoolTest do
  use ExUnit.Case, async: true
  use Mimic

  alias TypesenseEx.Node
  alias TypesenseEx.NodePool
  alias TypesenseEx.NodeStore, as: Store

  @node %{host: "example.com", port: 5564, protocol: "https"}

  describe "node configuration" do
    test "empty configuration" do
      assert {:ok, _pid} = NodePool.start_link(%{})
    end

    test "invalid protocol" do
      node = Map.put(@node, :protocol, "http_yes")
      config = %{nodes: [node]}

      assert {:error,
              [
                %Drops.Validator.Messages.Error.Set{
                  errors: [
                    [
                      %Drops.Validator.Messages.Error.Type{
                        path: [:nodes, 0, :protocol],
                        text: "must be one of: http, https",
                        meta: [predicate: :in?, args: [["http", "https"], "http_yes"]]
                      }
                    ]
                  ]
                }
              ]} = TypesenseEx.NodePool.start_link(config)

      assert_missing_node_field(:protocol)
    end

    test "invalid port" do
      node = Map.put(@node, :port, "z")
      config = %{nodes: [node]}

      assert {:error,
              [
                %Drops.Validator.Messages.Error.Set{
                  errors: [
                    [
                      %Drops.Validator.Messages.Error.Type{
                        path: [:nodes, 0, :port],
                        text: "must be an integer",
                        meta: [predicate: :type?, args: [:integer, "z"]]
                      }
                    ]
                  ]
                }
              ]} =
               TypesenseEx.NodePool.start_link(config)

      assert_missing_node_field(:port)
    end

    test "invalid host" do
      node = Map.put(@node, :host, 1)
      config = %{nodes: [node]}

      assert {:error,
              [
                %Drops.Validator.Messages.Error.Set{
                  errors: [
                    [
                      %Drops.Validator.Messages.Error.Type{
                        path: [:nodes, 0, :host],
                        text: "must be a string",
                        meta: [predicate: :type?, args: [:string, 1]]
                      }
                    ]
                  ]
                }
              ]} =
               TypesenseEx.NodePool.start_link(config)

      assert_missing_node_field(:host)
    end
  end

  def assert_missing_node_field(field) do
    node = Map.delete(@node, field)
    config = %{nodes: [node]}

    assert {:error,
            [
              %Drops.Validator.Messages.Error.Set{
                errors: [
                  [
                    %Drops.Validator.Messages.Error.Type{
                      path: [:nodes, 0, field],
                      text: "key must be present",
                      meta: [predicate: :has_key?, args: [[field]]]
                    }
                  ]
                ]
              }
            ]} =
             TypesenseEx.NodePool.start_link(config)
  end

  describe "with an empty configuration" do
    setup do
      pid = start_link_supervised!({NodePool, %{healthcheck_interval: 1}})
      %{supervisor_pid: pid}
    end

    test "start_link/1", ctx do
      assert Process.alive?(ctx.supervisor_pid)
    end

    test "add and remove nodes after boot" do
      assert {:error, :missing} == NodePool.next_node()

      NodePool.add_after(0, @node)

      Process.sleep(10)

      assert %Store.Node{id: 0, node: %{port: 5564, protocol: "https", host: "example.com"}} ==
               NodePool.next_node()

      NodePool.remove(0)

      assert {:error, :missing} == NodePool.next_node()
    end
  end

  describe "without a nearest node" do
    setup do
      node_configs = %{
        healthcheck_interval: 1,
        nodes: [
          %{host: "localhost", port: 8109, protocol: "http"},
          %{host: "localhost", port: 8108, protocol: "http"}
        ]
      }

      pid = start_link_supervised!({NodePool, node_configs})
      %{supervisor_pid: pid}
    end

    test "start_link/1", ctx do
      assert Process.alive?(ctx.supervisor_pid)
    end

    test "next_node/0" do
      assert %Store.Node{
               id: 1,
               node: %Node{
                 host: "localhost",
                 port: 8108,
                 protocol: "http"
               }
             } = NodePool.next_node()

      %Store.Node{
        id: 0,
        node: %Node{
          host: "localhost",
          port: 8109,
          protocol: "http"
        }
      } = NodePool.next_node()

      assert %Store.Node{
               id: 1,
               node: %Node{
                 host: "localhost",
                 port: 8108,
                 protocol: "http"
               }
             } = NodePool.next_node()
    end

    test "set_unhealthy/2" do
      assert %Store.Node{
               id: 1,
               node: %Node{
                 host: "localhost",
                 port: 8108,
                 protocol: "http"
               }
             } =
               node = NodePool.next_node()

      NodePool.set_unhealthy(node)

      assert %Store.Node{
               id: 0,
               node: %Node{
                 host: "localhost",
                 port: 8109,
                 protocol: "http"
               }
             } =
               node_two = NodePool.next_node()

      NodePool.set_unhealthy(node_two)

      assert {:error, :missing} = NodePool.next_node()

      Process.sleep(5)

      %Store.Node{
        id: 1,
        node: %Node{
          host: "localhost",
          port: 8108,
          protocol: "http"
        }
      } =
        NodePool.next_node()
    end
  end

  describe "with a nearest node" do
    setup do
      node_configs = %{
        healthcheck_interval: 1,
        nearest_node: %{host: "localhost", port: 8110, protocol: "http"},
        nodes: [
          %{host: "localhost", port: 8109, protocol: "http"}
        ]
      }

      pid = start_link_supervised!({NodePool, node_configs})
      %{supervisor_pid: pid}
    end

    test "start_link/1", ctx do
      assert Process.alive?(ctx.supervisor_pid)
    end

    test "next_node/0" do
      assert %Store.Node{
               id: :nearest_node,
               node: %Node{
                 host: "localhost",
                 port: 8110,
                 protocol: "http"
               }
             } = NodePool.next_node()

      assert %Store.Node{
               id: :nearest_node,
               node: %Node{
                 host: "localhost",
                 port: 8110,
                 protocol: "http"
               }
             } = NodePool.next_node()
    end

    test "set_unhealthy/2" do
      nearest_node = %Store.Node{
        id: :nearest_node,
        node: %Node{
          host: "localhost",
          port: 8110,
          protocol: "http"
        }
      }

      assert nearest_node == NodePool.next_node()

      NodePool.set_unhealthy(nearest_node)

      %Store.Node{
        id: 0,
        node: %Node{
          host: "localhost",
          port: 8109,
          protocol: "http"
        }
      } =
        node_8109 =
        NodePool.next_node()

      NodePool.set_unhealthy(node_8109)

      assert {:error, :missing} = NodePool.next_node()

      Process.sleep(10)

      assert nearest_node == NodePool.next_node()

      assert %TypesenseEx.NodeStore.Node{
               id: :nearest_node,
               node: %Node{
                 host: "localhost",
                 port: 8110,
                 protocol: "http"
               }
             } = NodePool.next_node()
    end
  end

  describe "with a nearest node and no nodes" do
    setup do
      node_configs = %{
        nearest_node: %{host: "localhost", port: 8177, protocol: "http"},
        nodes: []
      }

      pid = start_link_supervised!({NodePool, node_configs})
      %{supervisor_pid: pid}
    end

    test "start_link/1", ctx do
      assert Process.alive?(ctx.supervisor_pid)
    end

    test "next_node/0" do
      assert %Store.Node{
               id: :nearest_node,
               node: %Node{
                 host: "localhost",
                 port: 8177,
                 protocol: "http"
               }
             } = NodePool.next_node()

      assert %Store.Node{
               id: :nearest_node,
               node: %Node{
                 host: "localhost",
                 port: 8177,
                 protocol: "http"
               }
             } = NodePool.next_node()
    end

    test "set_unhealthy/2" do
      %Store.Node{
        id: :nearest_node,
        node: %Node{
          host: "localhost",
          port: 8177,
          protocol: "http"
        }
      } =
        node = NodePool.next_node()

      NodePool.set_unhealthy(node)

      assert {:error, :missing} = NodePool.next_node()
    end
  end
end
