defmodule Typesense.DocumentTest do
  use TypesenseCase, async: false
  alias Typesense.Documents
  alias Typesense.MockHttp

  setup do
    _pid = start_link_supervised!({Typesense.Client, @minimal_valid_config})
    :ok
  end

  test "create/2" do
    expected_options = [
      method: :post,
      url: "https://localhost:8107/collections/foo/documents",
      query: [],
      body: "{\"id\":0,\"location_name\":\"Jeff's Litterbox Hotel 0\",\"num_employees\":0}",
      headers: [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "application/json"}]
    ]

    expect(expected_options)

    doc = docs(1) |> List.first()
    Documents.create("foo", doc)
  end

  test "upsert/3" do
    expected_options = [
      {:method, :post},
      {:url, "https://localhost:8107/collections/foo/documents"},
      {:query, [action: :upsert]},
      {:body, "{\"id\":0,\"location_name\":\"Jeff's Litterbox Hotel 0\",\"num_employees\":0}"},
      {:headers, [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "application/json"}]}
    ]

    expect(expected_options)

    doc = docs(1) |> List.first()
    Documents.upsert("foo", doc)
  end

  test "update/3" do
    expected_options = [
      {:method, :post},
      {:url, "https://localhost:8107/collections/foo/documents"},
      {:query, [action: :update]},
      {:body, "{\"id\":0,\"location_name\":\"Jeff's Litterbox Hotel 0\",\"num_employees\":0}"},
      {:headers, [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "application/json"}]}
    ]

    expect(expected_options)

    doc = docs(1) |> List.first()
    Documents.update("foo", doc)
  end

  test "partial_update/3" do
    expected_options = [
      {:method, :patch},
      {:url, "https://localhost:8107/collections/foo/documents/0"},
      {:query, []},
      {:body, "{\"id\":0,\"location_name\":\"Jeff's Litterbox Hotel 0\",\"num_employees\":0}"},
      {:headers, [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "application/json"}]}
    ]

    expect(expected_options)

    doc = docs(1) |> List.first()
    Documents.partial_update("foo", doc)
  end

  test "retrieve/3" do
    expected_options = [
      {:method, :patch},
      {:url, "https://localhost:8107/collections/foo/documents/0"},
      {:query, []},
      {:body, nil},
      {:headers, [{"X-TYPESENSE-API-KEY", "123"}]}
    ]

    expect(expected_options)

    Documents.retrieve("foo", "0")
  end

  test "delete/2 when is_integer(document_id) " do
    expected_options = [
      {:method, :delete},
      {:url, "https://localhost:8107/collections/foo/documents"},
      {:query, "0"},
      {:body, nil},
      {:headers, [{"X-TYPESENSE-API-KEY", "123"}]}
    ]

    expect(expected_options)

    Documents.delete("foo", "0")
  end

  test "delete/2 " do
    expected_options = [
      {:method, :delete},
      {:url, "https://localhost:8107/collections/foo/documents"},
      {:query, %{filter_by: "foo"}},
      {:body, nil},
      {:headers, [{"X-TYPESENSE-API-KEY", "123"}]}
    ]

    expect(expected_options)

    Documents.delete("foo", %{filter_by: "foo"})
  end

  test "search/2 " do
    expected_options = [
      {:method, :delete},
      {:url, "https://localhost:8107/collections/foo/documents"},
      {:query, %{q: "foo", query_by: "title"}},
      {:body, nil},
      {:headers, [{"X-TYPESENSE-API-KEY", "123"}]}
    ]

    expect(expected_options)

    Documents.delete("foo", %{q: "foo", query_by: "title"})
  end

  test "import_documents/3" do
    expected_options = [
      method: :post,
      url: "https://localhost:8107/collections/companies/documents/import",
      query: [action: :insert],
      body:
        "{\"id\":0,\"location_name\":\"Jeff's Litterbox Hotel 0\",\"num_employees\":0}\n{\"id\":1,\"location_name\":\"Jeff's Litterbox Hotel 1\",\"num_employees\":1}\n{\"id\":2,\"location_name\":\"Jeff's Litterbox Hotel 2\",\"num_employees\":2}",
      headers: [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "text/plain"}]
    ]

    expect(expected_options)

    Documents.import_documents("companies", docs(2), action: :insert)
  end

  test "import_documents/3 with JSONL" do
    expected_options = [
      {:method, :post},
      {:url, "https://localhost:8107/collections/companies/documents/import"},
      {:query, [action: :insert]},
      {:body,
       "{\"id\": \"1\", \"location_name\": \"Jeff's Litterbox Hotel 0\", num_employees: 1}\n"},
      {:headers, [{"X-TYPESENSE-API-KEY", "123"}, {"Content-Type", "text/plain"}]}
    ]

    expect(expected_options)

    docs = """
    {"id": "1", "location_name": "Jeff's Litterbox Hotel 0", num_employees: 1}
    """

    Documents.import_documents("companies", docs, action: :insert)
  end

  test "import_documents/3 with no documents given" do
    assert {:error, "No documents were given"} =
             Documents.import_documents("companies", [], action: :insert)
  end

  test "export_documents/2" do
    expected_options = [
      {:method, :get},
      {:url, "https://localhost:8107/collections/companies/documents/export"},
      {:query, []},
      {:body, nil},
      {:headers, [{"X-TYPESENSE-API-KEY", "123"}]}
    ]

    expect(expected_options)

    Documents.export_documents("companies")
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
        "location_name" => "Jeff's Litterbox Hotel #{index}",
        "num_employees" => index
      }
    end)
  end
end
