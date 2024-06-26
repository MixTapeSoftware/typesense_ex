defmodule TypesenseEx.DocumentTest do
  use TypesenseExCase
  alias TypesenseEx.Documents

  setup_all do
    node_configs = %{
      api_key: "123",
      nodes: [
        %{host: "localhost", port: 8107, protocol: "https"}
      ]
    }

    start_link_supervised!({TypesenseEx, node_configs})

    :ok
  end

  test "create/3" do
    expected_options = [
      method: :post,
      url: "https://localhost:8107/collections/companies/documents",
      query: [],
      body: "{\"id\":0,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":0}",
      headers: [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "application/json"}]
    ]

    expect(expected_options)

    doc = docs(1) |> List.first()
    Documents.create("companies", doc)
  end

  test "imports some documents" do
    expected_options = [
      method: :post,
      url: "https://localhost:8107/collections/companies/documents/import",
      query: [action: :create],
      body:
        "{\"id\":0,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":0}\n{\"id\":1,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":1}\n{\"id\":2,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":2}",
      headers: [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "text/plain"}]
    ]

    expect(expected_options)

    Documents.import_documents("companies", docs(2), action: :create)
  end

  test "upsert/3" do
    expected_options = [
      method: :post,
      url: "https://localhost:8107/collections/companies/documents",
      query: [{:action, :upsert}],
      body: "{\"id\":0,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":0}",
      headers: [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "application/json"}]
    ]

    expect(expected_options)

    doc = docs(1) |> List.first()
    Documents.upsert("companies", doc)
  end

  test "update/3" do
    expected_options = [
      method: :post,
      url: "https://localhost:8107/collections/companies/documents",
      query: [{:action, :update}],
      body: "{\"id\":0,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":0}",
      headers: [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "application/json"}]
    ]

    expect(expected_options)

    doc = docs(1) |> List.first()
    Documents.update("companies", doc)
  end

  test "partial_update/3" do
    expected_options = [
      method: :patch,
      url: "https://localhost:8107/collections/companies/documents/0",
      query: [],
      body: "{\"id\":0,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":0}",
      headers: [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "application/json"}]
    ]

    expect(expected_options)

    doc = docs(1) |> List.first()
    Documents.partial_update("companies", doc)

    expect(
      method: :patch,
      url: "https://localhost:8107/collections/companies/documents/1",
      query: [],
      body: "{\"id\":1,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":0}",
      headers: [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "application/json"}]
    )

    doc = docs(1) |> List.first() |> Map.delete("id") |> Map.put(:id, 1)
    Documents.partial_update("companies", doc)
  end

  def expect(expected_options) do
    Tesla
    |> expect(:request, 1, fn _client, options ->
      assert expected_options == options
      {:ok, %Tesla.Env{status: 200, body: "{\"results\": []}"}}
    end)
  end

  test "get/3" do
    expected_options = [
      method: :get,
      url: "https://localhost:8107/collections/companies/documents/0",
      query: [],
      body: nil,
      headers: [{"X-TYPESENSE-API-KEY", "123"}]
    ]

    expect(expected_options)

    docs(1) |> List.first()
    Documents.get("companies", 0)
  end

  test "delete/3" do
    expected_options = [
      method: :delete,
      url: "https://localhost:8107/collections/companies/documents/0",
      query: [],
      body: nil,
      headers: [{"X-TYPESENSE-API-KEY", "123"}]
    ]

    expect(expected_options)

    docs(1) |> List.first()
    Documents.delete("companies", 0)

    expect(
      method: :delete,
      url: "https://localhost:8107/collections/companies/documents",
      query: %{"q" => "*", "filter_by" => "num_employees:1"},
      body: nil,
      headers: [{"X-TYPESENSE-API-KEY", "123"}]
    )

    docs(1) |> List.first()
    Documents.delete("companies", %{"q" => "*", "filter_by" => "num_employees:1"})
  end

  test "search/3" do
    expected_options = [
      method: :get,
      url: "https://localhost:8107/collections/companies/documents/search",
      query: %{"filter_by" => "num_employees:1", "q" => "*"},
      body: nil,
      headers: [{"X-TYPESENSE-API-KEY", "123"}]
    ]

    expect(expected_options)

    docs(1) |> List.first()
    Documents.search("companies", %{"q" => "*", "filter_by" => "num_employees:1"})
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

  describe "importing documents" do
    test "no documents given" do
      assert {:error, "No documents were given"} = Documents.import_documents("companies", [])
    end

    test "a list of documents" do
      expected_options = [
        method: :post,
        url: "https://localhost:8107/collections/companies/documents/import",
        query: [{:action, :create}],
        body:
          "{\"id\":0,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":0}\n{\"id\":1,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":1}\n{\"id\":2,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":2}\n{\"id\":3,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":3}",
        headers: [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "text/plain"}]
      ]

      expect(expected_options)

      docs = docs(3)
      assert {:ok, %{"results" => []}} = Documents.import_documents("companies", docs)
    end

    test "a JSON string" do
      expected_options = [
        method: :post,
        url: "https://localhost:8107/collections/companies/documents/import",
        query: [{:action, :create}],
        body:
          "{\"id\":0,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":0}\n{\"id\":1,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":1}\n{\"id\":2,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":2}\n{\"id\":3,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":3}",
        headers: [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "text/plain"}]
      ]

      expect(expected_options)

      docs =
        "{\"id\":0,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":0}\n{\"id\":1,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":1}\n{\"id\":2,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":2}\n{\"id\":3,\"location_name\":\"Jeff's Litterbox Hotel\",\"num_employees\":3}"

      Documents.import_documents("companies", docs)
    end
  end

  test "export_documents/2" do
    expected_options = [
      method: :get,
      url: "https://localhost:8107/collections/companies/documents/export",
      query: %{"filter_by" => "num_employees:>100", "q" => "*"},
      body: nil,
      headers: [{"X-TYPESENSE-API-KEY", "123"}]
    ]

    expect(expected_options)
    Documents.export_documents("companies", %{"q" => "*", "filter_by" => "num_employees:>100"})
  end
end
