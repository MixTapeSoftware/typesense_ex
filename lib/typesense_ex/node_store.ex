defmodule TypesenseEx.NodeStore do
  use Drops.Contract

  alias TypesenseEx.Store

  @node_registry_table :typesense_ex_node_registry
  @metadata_table :typesense_ex_metadata
  @metadata_fields [
    :current_node,
    :nearest_node,
    :healthcheck_interval
  ]

  defmodule Types.Node do
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

  defmodule Node do
    defstruct [:id, :node]
  end

  alias Node, as: StoreNode

  def init() do
    Store.init(@node_registry_table)
    Store.init(@metadata_table)
  end

  def first_node() do
    Store.first(@node_registry_table) |> to_result()
  end

  def get(key) do
    table_for(key) |> Store.get(key) |> to_result()
  end

  def add(key, value) do
    table_for(key) |> Store.add(key, value)
  end

  def remove(key) do
    table_for(key) |> Store.remove(key)
  end

  def replace(key, value) do
    table_for(key) |> Store.replace(key, value)
  end

  def next_node() do
    with {:ok, current_node} <- maybe_get_current_node(),
         {:ok, next_node} <- next_node(current_node) do
      {:ok, next_node}
    end
  end

  def next_node(%Node{id: id}) do
    next_node = table_for(id) |> Store.next(id) |> to_result()

    case next_node do
      {:error, :missing} -> first_node()
      result -> result
    end
  end

  # Handle starting with an empty config
  defp maybe_get_current_node() do
    case get(:current_node) do
      {:error, :missing} -> first_node()
      {:ok, %StoreNode{node: node}} -> {:ok, node}
    end
  end

  defp table_for(key) when key in @metadata_fields, do: @metadata_table

  defp table_for(_key), do: @node_registry_table

  defp to_result(store_item) do
    case store_item do
      {:ok, {id, node}} when id in [:current_node, :nearest_node] or is_integer(id) ->
        {:ok, struct(StoreNode, %{id: id, node: node})}

      # Non-node metadata items
      {:ok, {_key, value}} ->
        value

      error ->
        error
    end
  end
end
