defmodule Typesense.Collections do
  @moduledoc """
  Create and retrieve Typesense collections
  """
  alias Typesense.Request

  # We could use Ecto embedded schemas
  # to validate these schemas. For now,
  # we will just accept maps
  @type schema :: map()
  @type collection_name :: String.t()
  @type response :: Request.response()

  @doc """
  Create a collection
  """
  @spec(create(schema()) :: {:ok, schema()}, {:error, any})
  def create(schema) do
    Request.execute(:post, resource_path(), schema)
  end

  @doc """
  Lists all collection schemas
  """
  @spec retrieve() :: response()
  def retrieve do
    Request.execute(:get, resource_path())
  end

  @doc """
  Get a single collection schema
  """
  @spec retrieve(collection_name()) :: response()
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
  @spec update(collection_name(), schema()) :: response()
  def update(collection, schema) do
    Request.execute(:patch, collection_path(collection), schema)
  end

  @doc """
  Delete a collection
  """
  @spec delete(collection_name()) :: response()
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

  @spec collection_path(collection_name()) :: String.t()
  defp collection_path(collection_name) do
    "#{resource_path()}/#{collection_name}"
  end
end
