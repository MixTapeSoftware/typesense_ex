defmodule TypesenseEx.NodePool do
  @moduledoc """
  A pool that returns a round-robbin response of typesense nodes
  """

  use Drops.Contract
  use GenServer

  alias __MODULE__
  alias TypesenseEx.Node
  alias TypesenseEx.NodeStore, as: Store

  defstruct [:nearest_node, nodes: [], healthcheck_interval: 2_000]

  defmodule Types.Node do
    @moduledoc """
    A Drops Type module
    """
    use Drops.Type, %{
      required(:port) => integer(),
      required(:host) => string(),
      required(:protocol) => string(in?: ["http", "https"])
    }
  end

  schema do
    %{
      optional(:healthcheck_interval) => integer(gt?: 0),
      optional(:nearest_node) => Types.Node,
      optional(:nodes) => list(Types.Node)
    }
  end

  def start_link(params \\ %{}) do
    case NodePool.conform(params) do
      {:ok, config} ->
        node_pool = struct(NodePool, config)
        GenServer.start_link(NodePool, node_pool, name: NodePool)

      errors ->
        errors
    end
  end

  @doc """
  Get the next available node

  Each request to this function increments the pointer globally.
  """
  def next_node do
    case Store.get(:nearest_node) do
      {:ok, nearest_node} -> nearest_node
      {:error, :missing} -> get_and_set_next_node()
    end
  end

  def set_unhealthy(%Store.Node{id: id, node: node}) do
    remove(id)
    add_after(id, node)
  end

  @doc """
  Adds a node with a given id into the pool.

  Note: `:current_node` and `:nearest_node` may be set here as well
  by passing one of these atoms as the id.
  """
  def add_after(id, node) do
    milliseconds = Store.get(:healthcheck_interval)
    Process.send_after(NodePool, {:add, id, node}, milliseconds)
  end

  def remove(key) do
    GenServer.call(NodePool, {:remove, key})
  end

  @impl true
  def init(node_pool) do
    Store.init()

    Store.add(:healthcheck_interval, node_pool.healthcheck_interval)

    init_nodes(node_pool)
    {:ok, []}
  end

  @impl true
  def handle_call({:remove, key}, _from, state) do
    Store.remove(key)
    {:reply, %{}, state}
  end

  @impl true
  def handle_call({:replace, key, value}, _from, state) do
    Store.replace(key, value)
    {:reply, %{}, state}
  end

  @impl true
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

  defp init_nodes(node_pool) do
    %NodePool{nodes: nodes, nearest_node: nearest_node} = node_pool

    if not is_nil(nearest_node) do
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
        {:error, :missing} -> nil
      end

    Store.add(:current_node, current_node)
  end

  defp set_current_node(node) do
    replace(:current_node, node)
  end

  defp replace(key, value) do
    GenServer.call(NodePool, {:replace, key, value})
  end
end
