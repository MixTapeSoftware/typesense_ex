defmodule Typesense.Collections do
  alias Typesense.Request

  @path "/collections"

  def create(schema) do
    Request.execute(:post, @path, schema)
  end

  def retrieve do
    Request.execute(:get, @path)
  end
end
