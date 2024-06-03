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
    add(:nearest_node, nearest_node)

    [first_node | _rest] = nodes

    nodes
    |> Enum.with_index()
    |> Enum.each(fn {node, nid} -> add({:node, nid}, node) end)

    add(:current_node, {0, first_node})
  end

  defp current_nid, do: get(:current_nid)

  defp nodes do
    match_spec = [{{{:node, :"$1"}, :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}]
    :ets.select(@table, match_spec)

    :ets.select(@table, match_spec) |> Enum.map(fn {_nid, node, _pid} -> node end)
  end

  defp set_current_node(node) do
    remove(:current_node)
    add(:current_node, node)
  end

  defp add_node(node) do
    add({:node, node.id}, node)
  end

  defp remove_node(node) do
    remove({:node, node.id})

    [first_node | _rest] = nodes()
    set_current_node(first_node)
  end

  defp remove(name) do
    :ets.delete(@table, name)
  end

  defp add(name, value) do
    :ets.insert(@table, {name, value, self()})
  end

  defp get(name) do
    case :ets.lookup(@table, name) do
      [] -> {:error, :missing}
      [value] = results -> {:ok, value}
    end
  end

  def next_node do
    maybe_get_nodes = fn ->
      case nodes() do
        [] -> {:error, :no_healthy_nodes_available}
        nodes -> {:ok, nodes}
      end
    end

    get_next_index_node = fn nodes ->
      current_node = current_node()
      nodes_with_index = nodes |> Enum.with_index()

      current_index =
        nodes_with_index
        |> Enum.reduce(0, fn
          {^current_node, index}, _acc ->
            index

          _node, acc ->
            acc
        end)

      node_count = Enum.length(nodes)

      next_index = current_index + 1

      valid_next_index =
        if next_index > node_count - 1 do
          0
        else
          next_index
        end

      {next_node, _index} =
        Enum.find(nodes_with_index, fn {_node, index} ->
          index == valid_next_index
        end)

      next_node
    end

    with {:ok, nodes} <- maybe_get_nodes.() do
      get_next_index_node.(nodes)
    end
  end

  def next_nid() do
    nodes = nodes()

    next_nid = current_nid + 1
    node_count = Enum.count(nodes)

    next_node_exists = Enum.any?(nodes, fn {nid, _node} -> nid == next_nid end)

    if next_node_exists && next_nid <= node_count - 1 do
      next_nid
    else
      0
    end
  end

  defp get_node(nid) do
    with {:ok, node} <- get({:node, nid})

    case get({:node, id}) do
      # If the node isn't there, start over
      nil -> {:error}
      node -> node
    end
  end

  def set_unhealthy(nid, seconds \\ 2) do
    node = get_node(nid)
    remove_node(node)

    Process.send_after(self(), {:add, node}, seconds)
  end

  def handle_call({:add, node}, _from, state) do
    %{ids: ids} = state
    new_ids = [id | ids]
    add()
    {:reply, %{}, %{}}
  end

  def handle_call({:remove, id}, _from, state) do
    %{ids: ids} = state
    Registry.unregister(TypesenseEx.NodeRegistry, id)
    new_ids = Enum.reject(ids, &(&1 == id))

    # We reset current_id to force next_node to pick a valid node from ids
    {:reply, new_ids, %{state | ids: new_ids, current_id: nil}}
  end

  def handle_call(:ids, _from, state) do
    %{ids: ids} = state
    {:reply, ids, state}
  end

  # TODO: account for nearest_node
  # def handle_call(:next_node, _from, %{ids: ids} = state) when ids == [] do
  #   {:reply, {nil, nil}, %{state | current_id: nil}}
  # end

  def handle_call(:next_node, _from, state) do
    nid = next_nid(state)

    node =
      case Registry.lookup(TypesenseEx.NodeRegistry, nid) do
        [{_pid, node}] -> node
        [] -> nil
      end

    new_state =
      if nid == @nearest_node do
        state
      else
        %{state | current_id: nid}
      end

    {:reply, {nid, node}, new_state}
  end

  defp init_nodes(config) do
    %ClientConfig{nodes: node_configs, nearest_node: nearest_node_config} = config

    all_node_configs =
      if is_nil(nearest_node_config) do
        node_configs
      else
        [nearest_node_config | node_configs]
      end

    all_node_configs
    |> Enum.uniq()
    |> Enum.with_index()
    |> Enum.map(fn {node_config, i} ->
      node = to_node(node_config)
      next_id = i + 1

      nid =
        if node_config == nearest_node_config do
          @nearest_node
        else
          next_id
        end

      {:ok, _} = Registry.register(TypesenseEx.NodeRegistry, nid, node)

      if nid == @nearest_node do
      end

      nid
    end)
  end

  defp next_nid(state) do
    %{ids: ids, current_id: current_id} = state
    nearest_node = nearest_node(ids)

    if nearest_node do
      nearest_node
    else
      next_nid(current_id, ids)
    end
  end

  defp next_nid(nil, ids) do
    nodes(ids) |> List.first()
  end

  defp next_nid(current_id, ids) do
    node_count = node_count(ids)
    rem(current_id, node_count) + 1
  end

  defp node_count(ids) do
    nodes(ids) |> Enum.count()
  end

  defp nodes(ids) do
    Enum.filter(ids, &(&1 !== @nearest_node))
  end

  defp nearest_node(ids) do
    Enum.find(ids, &(&1 == @nearest_node))
  end

  defp to_node(nil), do: %Node{}

  defp to_node(config), do: Node.new(config)

  defp to_config(config) do
    config
    |> ClientConfig.new()
    |> ClientConfig.validate()
  end
end
