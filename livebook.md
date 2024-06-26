# TypesenseEx

```elixir
Mix.install([
  {:typesense_ex, git: "https://github.com/MixTapeSoftware/typesense_ex"}
])
```

## Start Typesense Locally

If you have Docker installed locally ([Docker installation instructions](https://docs.docker.com/engine/install/)), you can boot a local server using the TypesenseEx `docker-compose.yml` file. Notice that we're setting an API key. We'll used this key below, so **be sure to use the same key** if you use a different installation/boot method.

```bash
cd typesense_ex; \
export TYPESENSE_EX_API_KEY="ABC_123_DO_REI_MI_BABY_YOU_AND_ME"; \
docker compose up
```

For a complete list of installation methods, please see the [Typesense Docs](https://typesense.org/docs/guide/install-typesense.html).

## Start the TypesenseEx Servers

The TypesenseEx supervisor is just a wrapper around the `NodePool` and `Request` GenServers. `NodePool` holds configuration associated with access to Typesense Nodes and contains an Elixir-based round-robbin load balancer. Configuration is stored in `ets` for fast, concurrent read performance.

```elixir
  config = %{
    api_key: "ABC_123_DO_REI_MI_BABY_YOU_AND_ME",
    nodes: [
      %{host: "localhost", port: 8108, protocol: "http"}
    ]
  }

children = [
  {TypesenseEx, config}
]

{:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)

```

<!-- livebook:{"branch_parent_index":1} -->

## Collections

From the Typesense docs:

> In Typesense, every record you index is called a Document and a group of documents with similar fields is called a Collection. A Collection is roughly equivalent to a table in a relational database.

See the complete collections documentation [here](https://typesense.org/docs/0.24.0/api/collections.html#with-pre-defined-schema).

```elixir
schema = %{
  name: "companies",
  fields: [
    %{name: "company_name", type: "string"},
    %{name: "num_employees", type: "int32"},
    %{name: "country", type: "string", facet: true},
  ],
  default_sorting_field: "num_employees"
}

TypesenseEx.Collections.create(schema)
```

<!-- livebook:{"branch_parent_index":1} -->

## Create and Manage Documents

Records stored in Typesense are called "documents."

```elixir
document = %{
  id: "1170",
  company_name: "Jeff's Extra Toothy Kitteh Treats",
  num_employees: 1,
  country: "US"
}

TypesenseEx.Documents.create("companies", document)
```

```elixir
document = %{
  id: "1170",
  company_name: "Jeff's Extra Really Big Toothy Kitteh Treats",
  num_employees: 1,
  country: "US"
}

TypesenseEx.Documents.update("companies", document)
```

```elixir
document = %{
  id: "1170",
  num_employees: 10,
}

TypesenseEx.Documents.partial_update("companies", document)
```

```elixir
TypesenseEx.Documents.delete("companies", "1170")
```

```elixir
document = %{
  id: "1170",
  company_name: "Jeff's Extra Toothy Kitteh Treats",
  num_employees: 100,
  country: "US"
}

TypesenseEx.Documents.create("companies", document)
TypesenseEx.Documents.delete("companies", %{"q" => "*", "filter_by" => "num_employees:>99"})


```

```elixir
  documents = [
    %{
      id: "1171",
      company_name: "Perseus's House of Fangs",
      num_employees: 1,
      country: "US"
    },
    %{
      id: "1172",
      company_name: "Southwestern Tenderpaw Solutions",
      num_employees: 1,
      country: "US"
    }
  ]


TypesenseEx.Documents.import_documents("companies", documents)

```

For really large JSON data sets, we can take advantage of Typsenses's support for [JSON Lines](https://jsonlines.org/examples/)

```elixir
  documents = [
    %{
      id: "1173",
      company_name: "Mr. Luxurious Enterprises",
      num_employees: 1,
      country: "US"
    },
    %{
      id: "1174",
      company_name: "Raul's Meownager Training Institute",
      num_employees: 1,
      country: "US"
    }
  ]
# pretend we are loading this from a very large file 😺
jsonl_docs =
  Enum.map(documents, fn doc -> Jason.encode!(doc) end)
  |> Enum.join("\n")

TypesenseEx.Documents.import_documents("companies", jsonl_docs)

```

```elixir
TypesenseEx.Documents.export_documents("companies")

```

<!-- livebook:{"branch_parent_index":1} -->

## Search and Retrieve Documents

See the [Typesense Docs](https://typesense.org/docs/26.0/api/search.html) for all the ways you can search.

```elixir
TypesenseEx.Documents.search("companies", %{"q" => "*"})
```

```elixir
TypesenseEx.Documents.get("companies", "1170")
```
