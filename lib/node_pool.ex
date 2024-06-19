defmodule TypesenseEx.NodePool do
  @moduledoc """
  A pool that returns a round-robbin response of typesense nodes
  """
  use GenServer
  alias __MODULE__
  alias TypesenseEx.ClientConfig
  alias TypesenseEx.Node
  alias TypesenseEx.NodeStore, as: Store

  def start_link(config) do
    case to_config(config) do
      {:ok, config} ->
        GenServer.start_link(NodePool, config, name: NodePool)

      errors ->
        errors
    end
  end

  def init(config) do
    Store.init()

    init_nodes(config)
    {:ok, []}
  end

  @doc """
  Get the next available node

  Each request to this function increments the pointer globally.
  """
  def next_node do
    case Store.get(:nearest_node) do
      {:ok, nearest_node} ->
        {:nearest_node, nearest_node}

      {:error, :missing} ->
        get_and_set_next_node()
    end
  end

  def set_unhealthy(node, milliseconds \\ 2000)

  def set_unhealthy({:nearest_node, node}, milliseconds) do
    remove(:nearest_node)

    Process.send_after(NodePool, {:add, :nearest_node, node}, milliseconds)
  end

  def set_unhealthy({id, node}, milliseconds) do
    remove(id)
    add_in(id, node, milliseconds)
  end

  def handle_call({:remove, key}, _from, state) do
    Store.remove(key)
    {:reply, %{}, state}
  end

  def handle_call({:replace, key, value}, _from, state) do
    Store.replace(key, value)
    {:reply, %{}, state}
  end

  def handle_info({:add, key, value}, state) do
    Store.add(key, value)

    {:noreply, state}
  end

  defp get_and_set_next_node do
    with {:ok, next_node} <- Store.next_node() do
      set_current_node(next_node)
      next_node
    end
  end

  defp to_config(config) do
    config
    |> ClientConfig.new()
    |> ClientConfig.validate()
  end

  defp init_nodes(config) do
    %ClientConfig{nodes: nodes, nearest_node: nearest_node} = config

    if nearest_node do
      Store.add(:nearest_node, struct(Node, nearest_node))
    end

    nodes
    |> Enum.with_index()
    |> Enum.each(fn {node_config, id} ->
      node = struct(Node, node_config)
      Store.add(id, node)
    end)

    current_node =
      case Store.first_node() do
        {:ok, node} -> node
        missing -> missing
      end

    Store.add(:current_node, current_node)
  end

  defp set_current_node(node) do
    replace(:current_node, node)
  end

  # Our ordered set tables are protected, so all mutations
  # must happen in-process. Reads are concurrent and public.

  defp add_in(id, node, milliseconds) do
    Process.send_after(NodePool, {:add, id, node}, milliseconds)
  end

  defp replace(key, value) do
    GenServer.call(NodePool, {:replace, key, value})
  end

  defp remove(key) do
    GenServer.call(NodePool, {:remove, key})
  end
end
