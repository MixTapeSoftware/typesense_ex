defmodule Typesense.Documents do
  @moduledoc """
  Create and retrieve Typesense documents
  """
  alias Typesense.Collections
  alias Typesense.Request

  @type document_id :: String.t()
  @type document :: %{required(:id) => document_id(), required(atom()) => String.t()}
  @type collection_name :: Typesense.Collections.collection_name()
  @type params :: Request.params()
  @type response :: Request.response()

  @type search_params :: %{
          required(:q) => String.t(),
          required(:query_by) => String.t(),
          atom() => String.t()
        }
  @type delete_params :: %{
          required(:filter_by) => String.t(),
          atom() => String.t()
        }

  @spec create(collection_name(), document()) :: response()
  def create(collection, document) do
    path = endpoint_path(collection)
    Request.execute(:post, path, document)
  end

  @spec upsert(collection_name(), document(), params()) :: response()
  def upsert(collection, document, params \\ []) do
    modify(collection, document, params, :upsert)
  end

  @spec update(collection_name(), document(), params()) :: response()
  def update(collection, document, params \\ []) do
    modify(collection, document, params, :update)
  end

  @spec partial_update(collection_name(), document(), params()) :: response()
  def partial_update(collection, partial_document, params \\ []) do
    path = endpoint_path(collection, partial_document["id"])
    Request.execute(:patch, path, partial_document, params)
  end

  @spec retrieve(collection_name(), document_id(), params()) :: response()
  def retrieve(collection, document_id, params \\ []) do
    path = endpoint_path(collection, document_id)
    Request.execute(:patch, path, nil, params)
  end

  @spec delete(collection_name(), document_id()) :: response()
  def delete(collection, document_id) when is_integer(document_id) do
    document_path = endpoint_path(collection, document_id)
    Request.execute(:delete, document_path, nil)
  end

  @spec delete(collection_name(), delete_params()) :: response()
  def delete(collection, search_params) do
    document_path = endpoint_path(collection)
    Request.execute(:delete, document_path, nil, search_params)
  end

  @spec search(collection_name(), search_params()) :: response()
  def search(collection, search_params) do
    path = endpoint_path(collection, "search")
    Request.execute(:get, path, nil, search_params)
  end

  @doc """
  Import documents

  ## IMPORTANT NOTE & TIP

  All fields you mention in a collection's schema will be indexed in memory.

  There might be cases where you don't intend to search / filter / facet /
  group by a particular field and just want it to be stored (on disk) and
  returned as is when a document is a search hit. For eg: you can store image
  URLs in every document that you might use when displaying search results,
  but you might not want to text-search the actual URLs.

  You want to NOT mention these fields in the collection's schema or mark
  these fields as index: false (see fields schema parameter below) to mark
  it as an unindexed field. You can have any number of these additional
  unindexed fields in the documents when adding them to a collection - they
  will just be stored on disk, *and will not take up any memory*.
  """
  @spec import_documents(collection_name(), [document] | String.t(), params()) :: response()
  def import_documents(collection, documents, params \\ [])

  def import_documents(_collection, documents, _params) when documents == [] do
    {:error, "No documents were given"}
  end

  def import_documents(collection, documents, params) when is_list(documents) do
    jsonl_documents =
      documents
      |> Stream.map(&Jason.encode!/1)
      |> Enum.join("\n")

    import_documents(collection, jsonl_documents, params)
  end

  def import_documents(collection, documents, params) when is_binary(documents) do
    path = endpoint_path(collection, "import")
    Request.execute(:post, path, documents, params)
  end

  @spec export_documents(collection_name(), params()) :: response()
  def export_documents(collection, params \\ []) do
    path = endpoint_path(collection, "export")
    Request.execute(:get, path, nil, params)
  end

  @spec endpoint_path(collection_name(), atom() | String.t() | integer()) :: String.t()
  defp endpoint_path(collection_name, operation) do
    "#{endpoint_path(collection_name)}/#{operation}"
  end

  @spec endpoint_path(collection_name()) :: String.t()
  defp endpoint_path(collection_name) do
    "#{Collections.resource_path()}/#{collection_name}/documents"
  end

  @spec modify(collection_name(), document(), params(), atom()) :: response()
  defp modify(collection, document, params, action) do
    path = endpoint_path(collection)
    options = Keyword.merge(params, action: action)
    Request.execute(:post, path, document, options)
  end
end
