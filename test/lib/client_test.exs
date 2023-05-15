defmodule Typesense.ClientTest do
  use ExUnit.Case
  alias Typesense.Client
  alias Typesense.TypesenseNode

  doctest Client

  @valid_nodes [
    %{host: "localhost", port: "8107", protocol: "https"},
    %{host: "localhost", port: "8108", protocol: "https"},
    %{host: "localhost", port: "8109", protocol: "https"}
  ]

  @minimal_valid_config %{
    api_key: "123",
    nodes: @valid_nodes
  }

  test "start_link/1" do
    {:ok, pid} = Client.start_link(@minimal_valid_config)
    assert Process.alive?(pid)
  end

  test "start_link/1 with invalid config" do
    assert_misconfig(%{nodes: []}, "Configuration Contains an Empty Node List")
    assert_misconfig(%{}, "Configuration Missing Nodes")
    assert_misconfig(%{nodes: :nodes}, "Configuration Nodes Not a List")
  end

  test "start_link/1 with invalid nearest_node" do
    assert_misconfig(
      Map.merge(@minimal_valid_config, %{
        nearest_node: %{host_zzzz: "localhost", port: "8107", protocol: "https"}
      }),
      "Invalid Nearest Node Specification"
    )
  end

  test "start_link/1 with invalid nodes" do
    assert_misconfig(
      Map.merge(@minimal_valid_config, %{
        nodes: [%{host_zzz: "localhost", port: "8107", protocol: "https"}]
      }),
      "One or More Node Configurations Missing Data"
    )
  end

  test "start_link/1 with missing nodes" do
    assert_misconfig(
      Map.delete(@minimal_valid_config, :nodes),
      "Configuration Missing Node List"
    )
  end

  test "start_link/1 with invalid api_key" do
    assert_misconfig(
      Map.merge(@minimal_valid_config, %{api_key: 123}),
      "Configuration Missing API Key"
    )
  end

  test "next_node/0 retrieves valid nodes in order and rests when reaching the end" do
    {:ok, _pid} = Client.start_link(@minimal_valid_config)

    assert_next_node("8107", :healthy)
    assert_next_node("8108", :healthy)
    assert_next_node("8109", :healthy)
    assert_next_node("8107", :healthy)
  end

  test "set_unealthy/0 set_healthy/0 temporarily removes nodes from next_nodes" do
    {:ok, _pid} = Client.start_link(@minimal_valid_config)
    first_node_config = List.first(@valid_nodes)
    first_node = TypesenseNode.new(first_node_config)
    assert_next_node("8107", :healthy)
    assert_next_node("8108", :healthy)
    assert_next_node("8109", :healthy)

    Client.set_unhealthy(first_node)
    assert_next_node("8108", :healthy)
    assert_next_node("8109", :healthy)
    assert_next_node("8108", :healthy)

    Client.set_healthy(first_node)
    # There is still one good node in the stack
    # so we need to pop it of before we can get to
    # the newly healthy status 8107
    assert_next_node("8109", :healthy)
    assert_next_node("8107", :healthy)
  end

  test "set_healthy/0 is reset after healthcheck_interval_seconds has expired" do
    {:ok, _pid} =
      @minimal_valid_config
      |> Map.put(:healthcheck_interval_seconds, 0)
      |> Client.start_link()

    first_node = List.first(@valid_nodes) |> TypesenseNode.new()

    assert_next_node("8107", :healthy)
    Client.set_unhealthy(first_node)
    assert_next_node("8108", :healthy)
    assert_next_node("8109", :healthy)
    assert_next_node("8107", :maybe_healthy)
  end

  test "nearest_node is set healthy/unhealthy" do
    nearest_node = %{host: "localhost", port: "8110", protocol: "https"}

    {:ok, _pid} =
      @minimal_valid_config
      |> Map.put(:nearest_node, nearest_node)
      |> Client.start_link()

    assert_next_node("8110", :healthy)
    TypesenseNode.new(nearest_node) |> Client.set_unhealthy()
    assert_next_node("8107", :healthy)
    TypesenseNode.new(nearest_node) |> Client.set_healthy()
    assert_next_node("8110", :healthy)
  end

  def assert_next_node(port, status) do
    next_node = Client.next_node()
    assert port == next_node.port
    assert status == next_node.health_status
  end

  defp assert_misconfig(config, msg) do
    Process.flag(:trap_exit, true)
    assert {:error, msg} == Client.start_link(config)
    assert_receive {:EXIT, _pid, ^msg}
  end
end
