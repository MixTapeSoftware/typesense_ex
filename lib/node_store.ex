defmodule TypesenseEx.NodeStore do
  alias TypesenseEx.OrderedStore, as: Store

  @node_registry_table :typesense_ex_node_registry
  @metadata_table :typesense_ex_metadata
  @metadata_fields [
    :current_node,
    :nearest_node
  ]

  def init() do
    Store.init(@node_registry_table)
    Store.init(@metadata_table)
  end

  def first_node() do
    Store.first(@node_registry_table)
  end

  def get(key) do
    table_for(key) |> Store.get(key)
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
    with {:ok, current_node} <- get(:current_node),
         {:ok, next_node} <- next_node(current_node) do
      {:ok, next_node}
    end
  end

  def next_node({key, _node}) do
    next_node = table_for(key) |> Store.next(key)

    case next_node do
      {:error, :missing} ->
        first_node()

      result ->
        result
    end
  end

  defp table_for(key) when key in @metadata_fields, do: @metadata_table

  defp table_for(_key), do: @node_registry_table
end
