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

  @documents_path "/documents"

  @spec create(collection_name(), document(), params()) :: response()
  def create(collection, document, params \\ []) do
    path = endpoint_path(collection)
    Request.execute(:post, path, document, params)
  end

  @spec upsert(collection_name(), document(), params()) :: response()

  def upsert(collection, document, params \\ []) do
    modify(collection, document, params, :upsert)
  end

  def update(collection, document, params \\ []) do
    modify(collection, document, params, :update)
  end

  @spec update(collection_name(), document(), params()) :: response()
  def partial_update(collection, partial_document, params \\ []) do
    path = endpoint_path(collection, partial_document["id"])
    Request.execute(:patch, path, partial_document, params)
  end

  @spec update(collection_name(), document_id(), params()) :: response()
  def retrieve(collection, document_id, params \\ []) do
    path = endpoint_path(collection, document_id)
    Request.execute(:patch, path, "", params)
  end

  @spec delete(collection_name(), document_id()) :: response()
  def delete(collection, document_id) when is_integer(document_id) do
    document_path = endpoint_path(collection, document_id)
    Request.execute(:delete, document_path)
  end

  @spec delete(collection_name(), delete_params()) :: response()
  def delete(collection, search_params) do
    document_path = endpoint_path(collection)
    Request.execute(:delete, document_path, "", search_params)
  end

  @spec search(collection_name(), search_params()) :: response()
  def search(collection, search_params) do
    path = endpoint_path(collection, "search")
    Request.execute(:get, path, "", search_params)
  end

  @doc """
  Import documents

  Note: we can't use "import" here as it is a reserved kernel keyword
  """
  @spec import_documents(collection_name(), [document] | String.t(), params()) :: response()
  def import_documents(collection, documents, params \\ [])

  def import_documents(_collection, documents, _params) when documents == [] do
    {:error, "No documents were given"}
  end

  def import_documents(collection, documents, params) when is_list(documents) do
    jsonl_documents = Enum.map_join(documents, "\n", &Jason.encode!/1)

    import_documents(collection, jsonl_documents, params)
  end

  def import_documents(collection, documents, params) when is_binary(documents) do
    path = endpoint_path(collection, "import")
    Request.execute(:post, path, documents, params)
  end

  @spec export_documents(collection_name(), params()) :: response()
  def export_documents(collection, params \\ []) do
    path = endpoint_path(collection, "export")
    Request.execute(:get, path, "", params)
  end

  @spec endpoint_path(collection_name(), atom() | String.t() | integer()) :: String.t()
  defp endpoint_path(collection_name, operation) do
    "#{endpoint_path(collection_name)}/#{operation}"
  end

  @spec endpoint_path(collection_name()) :: String.t()
  defp endpoint_path(collection_name) do
    "#{Collections.resource_path()}/#{collection_name}/#{@documents_path}"
  end

  @spec modify(collection_name(), document(), params(), atom()) :: response()
  defp modify(collection, document, params, action) do
    path = endpoint_path(collection)
    upsert_options = Keyword.merge(params, action: action)
    Request.execute(:post, path, document, upsert_options)
  end
end
