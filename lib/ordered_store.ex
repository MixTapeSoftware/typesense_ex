defmodule TypesenseEx.OrderedStore do
  @moduledoc """
  A wrapper around an ordered ets store
  """
  @missing_error {:error, :missing}

  def init(table) do
    if :ets.info(table, :size) === :undefined do
      :ets.new(table, [:ordered_set, :protected, :named_table, read_concurrency: true])
    end
  end

  @doc """
  An add is the equivalent of a replace with an ets store.

  Adding an alias here so I don't eventually forget this fact.

  From the Erlang Docs:

  ```
  If the table type is ordered_set and the key of the inserted object
     compares equal to the key of any object in the table, the old object is
    replaced.
    ```
    [Erlang ets:insert/2](https://www.erlang.org/doc/apps/stdlib/ets.html#insert/2)
  """
  def replace(table, key, value) do
    add(table, key, value)
  end

  def first(table) do
    :ets.first_lookup(table) |> result()
  end

  def next(table, key) do
    :ets.next_lookup(table, key) |> result()
  end

  def get(table, key) do
    case :ets.lookup(table, key) do
      [] -> @missing_error
      [{_key, nil, _pid}] -> @missing_error
      [{_key, value, _pid}] -> {:ok, value}
    end
  end

  def add(table, key, value) do
    :ets.insert(table, {key, value, self()})
  end

  def remove(table, key) do
    :ets.delete(table, key)
  end

  defp result(result) do
    case result do
      :"$end_of_table" -> @missing_error
      {id, [{_id, node, _pid}]} -> {:ok, {id, node}}
    end
  end
end
