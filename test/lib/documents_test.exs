defmodule Typesense.DocumentTest do
  use TypesenseCase, async: true
  alias Typesense.Client
  alias Typesense.Documents
  alias Typesense.MockHttp

  setup do
    {:ok, _pid} = Client.start_link(@minimal_valid_config)

    :ok
  end

  test "create/3" do
    expected_options = [
      method: :post,
      url: "https://localhost:8107/collections/foo/documents",
      query: [],
      body: "{\"id\":0,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":0}",
      headers: [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "application/json"}]
    ]

    expect(expected_options)

    doc = docs(1) |> List.first()
    Documents.create("foo", doc)
  end

  test "imports some documents" do
    expected_options = [
      method: :post,
      url: "https://localhost:8107/collections/companies/documents/import",
      query: [action: :insert],
      body:
        "{\"id\":0,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":0}\n{\"id\":1,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":1}\n{\"id\":2,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":2}",
      headers: [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "text/plain"}]
    ]

    expect(expected_options)

    Documents.import_documents("companies", docs(2), action: :insert)
  end

  def expect(expected_options) do
    MockHttp
    |> expect(:request, 1, fn _client, options ->
      assert expected_options == options
      {:ok, %Tesla.Env{status: 200, body: "{\"results\": []}"}}
    end)
    |> expect(:client, 1, fn _middleware ->
      {:ok, %Tesla.Env{status: 200, body: "{\"results\": []}"}}
    end)
  end

  def docs(count) do
    Enum.map(0..count, fn index ->
      %{
        "id" => index,
        "location_name" => "Jeff's Litterbox Hotel",
        "num_employees" => index
      }
    end)
  end
end
