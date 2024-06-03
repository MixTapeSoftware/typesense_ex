defmodule TypesenseEx.NodePool do
  use GenServer
  alias __MODULE__
  alias TypesenseEx.ClientConfig
  alias TypesenseEx.Node

  # TODO: Instead of removing nodes, mark them as unhealthy
  # This way, we can use an unhealthy node in case no healthy nodes are available

  @doc """
  A special Registry ID for the nearest node

  We want to return the nearest node every time as long as it is
  in the Registry (that is, if it has been set and hasn't been
  put in time-out due it being marked unhealthy). So, we have
  a single handle on it.
  """
  @nearest_node :nearest_node
  @table :typesense_ex_node_registry

  def start_link(config) do
    case to_config(config) do
      {:ok, config} ->
        GenServer.start_link(NodePool, config, name: NodePool)

      errors ->
        errors
    end
  end

  def init(config) do
    init_bucket()
    init_nodes(config)
    {:ok, []}
  end

  def init_bucket() do
    if :ets.info(@table, :size) === :undefined do
      :ets.new(@table, [:set, :protected, :named_table])
    end
  end

  defp init_nodes(config) do
    %ClientConfig{nodes: nodes, nearest_node: nearest_node} = config

    if nearest_node do
      ets_add(:nearest_node, struct(Node, nearest_node))
    end

    nodes
    |> Enum.each(fn node_config ->
      node = struct(Node, node_config)
      ets_add({:node, node}, node)
    end)

    if nodes() != [] do
      [first_node | _rest] = nodes()

      ets_add(:current_node, first_node)
    end
  end

  defp current_node do
    get(:current_node)
  end

  def nodes do
    match_spec = [{{{:node, :"$1"}, :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}]
    :ets.select(@table, match_spec)

    :ets.select(@table, match_spec) |> Enum.map(fn {_nid, node, _pid} -> node end)
  end

  defp set_current_node(node) do
    remove(:current_node)
    add(:current_node, node)
  end

  defp remove_node(node) do
    remove({:node, node})
  end

  defp remove(name) do
    GenServer.call(NodePool, {:remove, name})
  end

  defp add(name, value) do
    GenServer.call(NodePool, {:add, name, value})
  end

  defp get(name) do
    case :ets.lookup(@table, name) do
      [] ->
        {:error, :missing}

      [{_key, nil, _pid}] ->
        {:error, :missing}

      [{_key, value, _pid}] ->
        {:ok, value}
    end
  end

  def next_node do
    maybe_get_nodes = fn ->
      case nodes() do
        [] -> {:error, :no_healthy_nodes_available}
        nodes -> {:ok, nodes}
      end
    end

    case get(:nearest_node) do
      {:ok, nearest_node} ->
        nearest_node

      _ ->
        with {:ok, nodes} <- maybe_get_nodes.() do
          next_node = next_node(nodes)
          set_current_node(next_node)

          next_node
        end
    end
  end

  def set_unhealthy(node, milliseconds \\ 2000) do
    with {:ok, nearest_node} <- get(:nearest_node),
         true <- nearest_node == node do
      remove(:nearest_node)

      Process.send_after(NodePool, {:add, :nearest_node, node}, milliseconds)
    end

    remove_node(node)
    Process.send_after(NodePool, {:add, {:node, node}, node}, milliseconds)
  end

  defp next_node(nodes) do
    {:ok, current_node} = current_node()

    current_index = Enum.find_index(nodes, fn node -> node == current_node end)

    current_index = current_index || 0

    next_index = rem(current_index + 1, length(nodes))

    {next_node, _} = nodes |> Enum.with_index() |> Enum.at(next_index)

    next_node
  end

  defp ets_add(name, value) do
    :ets.insert(@table, {name, value, self()})
  end

  def handle_call({:add, name, value}, _from, state) do
    ets_add(name, value)
    {:reply, %{}, state}
  end

  def handle_call({:remove, name}, _from, state) do
    :ets.delete(@table, name)
    {:reply, %{}, state}
  end

  def handle_info({:add, key, value}, state) do
    ets_add(key, value)

    {:noreply, state}
  end

  defp to_config(config) do
    config
    |> ClientConfig.new()
    |> ClientConfig.validate()
  end
end
