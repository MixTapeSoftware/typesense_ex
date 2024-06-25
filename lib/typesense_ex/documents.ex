defmodule TypesenseEx.Documents do
  @moduledoc """
  Create and retrieve Typesense documents
  """
  alias TypesenseEx.Collections
  alias TypesenseEx.Request

  def create(collection, document) do
    path = endpoint_path(collection)
    Request.execute(:post, path, document)
  end

  def upsert(collection, document, params \\ []) do
    modify(collection, document, params, :upsert)
  end

  def update(collection, document, params \\ []) do
    modify(collection, document, params, :update)
  end

  def partial_update(collection, partial_document, params \\ []) do
    path = endpoint_path(collection, partial_document["id"])
    Request.execute(:patch, path, partial_document, params)
  end

  def retrieve(collection, document_id, params \\ []) do
    path = endpoint_path(collection, document_id)
    Request.execute(:patch, path, nil, params)
  end

  def delete(collection, document_id) when is_integer(document_id) do
    document_path = endpoint_path(collection, document_id)
    Request.execute(:delete, document_path, nil)
  end

  def delete(collection, search_params) do
    document_path = endpoint_path(collection)
    Request.execute(:delete, document_path, nil, search_params)
  end

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

  def export_documents(collection, params \\ []) do
    path = endpoint_path(collection, "export")
    Request.execute(:get, path, nil, params)
  end

  defp endpoint_path(collection_name, operation) do
    "#{endpoint_path(collection_name)}/#{operation}"
  end

  defp endpoint_path(collection_name) do
    "#{Collections.resource_path()}/#{collection_name}/documents"
  end

  defp modify(collection, document, params, action) do
    path = endpoint_path(collection)
    options = Keyword.merge(params, action: action)
    Request.execute(:post, path, document, options)
  end
end
