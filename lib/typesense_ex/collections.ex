defmodule TypesenseEx.Collections do
  @moduledoc """
  Create and retrieve Typesense collections
  """
  alias TypesenseEx.Request

  @doc """
  Create a collection
  """
  def create(schema) do
    Request.execute(:post, resource_path(), schema)
  end

  @doc """
  Lists all collection schemas
  """
  def retrieve do
    Request.execute(:get, resource_path())
  end

  @doc """
  Get a single collection schema
  """
  def retrieve(collection) do
    Request.execute(:get, collection_path(collection))
  end

  @doc """
  Update a collection

  NOTE: Typesense currently __ONLY supports updating fields__.
  To update a field, you must first DROP it before adding
  it back to the schema. To DROP a field, use the `drop`
  directive:

  ```elixir
  ...
      {
        'name'  => 'num_employees',
        'drop'  => true
      },
  ...
  ```
  """
  def update(collection, schema) do
    Request.execute(:patch, collection_path(collection), schema)
  end

  @doc """
  Delete a collection
  """
  def delete(collection) do
    Request.execute(:delete, collection_path(collection))
  end

  @doc """
  The path to collections

  We expose this here for use in other modules, like Documents
  """
  def resource_path do
    "/collections"
  end

  defp collection_path(collection_name) do
    "#{resource_path()}/#{collection_name}"
  end
end
