# Typesense

(**EXPERIMENTAL / WORK IN PROGRESS**)

## Elixir bindings for the [Typesense REST Api](https://typesense.org/docs/0.24.1/api/).

Th package is incomplete and will continue to change for the near future.

### Why An Elixir Load Balancer?

In many cases an external load balancer may not be present. As a result,
`Typesense` implements an Elixir-based load balancer for Typesense nodes. Nodes
that are non-responsive after configurable set of retries and health check seconds
interval are marked as healthy and will not be retried for a period of time (also
configurable). All users of the application share the Client, causing node requests
to be distributed evenly across users.

## Installation and Configuration

### Install Typesense

Either [Install typesense locally](https://typesense.org/docs/guide/install-typesense.html) or
use the hosted version, [typesense cloud](https://cloud.typesense.org/).

**Example** of a docker-compose typesense instance with an api key configured:

```docker

version: "3.3"
services:
  typesense:
    image: typesense/typesense:0.24.0
    ports:
      - "127.0.0.1:8108:8108"
    volumes:
      - typesense:/data
    command: "--data-dir /data --api-key=MY_TYPESENSE_API_KEY --enable-cors"

volumes:
  typesense:
    driver: local
```

### Install the Package

```elixir
def deps do
  [
    {:typesense_ex, git: "git@github.com:GetAfterItApps/typesense.git"}
  ]
end
```

### Configuration

```elixir

config :my_app, :typesense,
  nodes: [%{host: "localhost", port: "8108", protocol: "http"}]
```

**Configuration Options**

| Name                         | Description                                                                                                                |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| nodes                        | (required) A list of typesense node configurations                                                                         |
| api_key                      | (recommended) A string representing the configured typesense api key (e.g. above it's "`MY_TYPESENSE_API_KEY`")            |
| connection_timeout_seconds   | [defaults to 10] Establishes how long Typesense should wait before retrying a request to a typesense node after timing out |
| num_retries                  | [defaults to 3] The number of retry attempts that should be made before marking a node unhealthy                           |
| retry_interval_seconds       | [defaults to 0.1] The number of seconds to wait between retries                                                            |
| healthcheck_interval_seconds | [defaults to 15] The number of seconds to wait before resuming requests for a node after it has been marked unhealthy      |

Add the Typesense to your supervision tree.

Note: configuration is passed into the client directly as recommended
in the [Mix Library Guidelines](https://hexdocs.pm/elixir/main/library-guidelines.html#avoid-application-configuration)

```elixir
  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      YourAppWeb.Telemetry,
      # Start the Ecto repository
      YourApp.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: YourApp.PubSub},
      # Start Finch
      {Finch, name: YourApp.Finch},
      # Start the Endpoint (http/https)
      YourAppWeb.Endpoint,
      {Typesense.Client, typesense_config()}

      # Start a worker by calling: YourApp.Worker.start_link(arg)
      # {YourApp.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: YourApp.Supervisor]
    Supervisor.start_link(children, opts)
  end


  defp typesense_config() do
    Application.get_env(:your_app, :typesense) |> Enum.into(%{})
    # Alternatively, you can just configure this here.
    # %{
    #   api_key: "MY_TYPESENSE_API_KEY",
    #   nodes: [%{host: "localhost", port: "8108", protocol: "http"}]
    # }
  end

```
### Optional Configuration

Typesense uses Tesla and Tesla is configurable to use other Adapters. e.g.:

```elixir
config :tesla, :adapter, {Tesla.Adapter.Finch, name: MyApp.Finch}

```

## Usage

Add a [Typesense Collection](https://typesense.org/docs/0.24.1/api/collections.html):

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

iex> Typesense.Collections.create(schema)
```

Add [Typesense Document](https://typesense.org/docs/0.24.1/api/documents.html)

```elixir
document = %{
  id: "1170",
  company_name: "Jeff's Extra Toothy Kitteh Treats",
  num_employees: 1,
  country: "US"
}

iex> Typesense.Documents.create("companies", document)
```

Search for Typesense Documents

```elixir

iex> Typesense.Documents.search("companies", %{q: "Jeffs", query_by: "company_name"})
```

## Todo

- [ ] Allow `Client` to dynamically add/remove nodes
- [ ] [`Multisearch`](https://typesense.org/docs/0.24.1/api/federated-multi-search.html)
- [ ] [`Api Keys` management](https://typesense.org/docs/0.24.1/api/api-keys.html)
- [ ] [`Curation` Overrides](https://typesense.org/docs/0.24.1/api/curation.html)
- [ ] [`Collection Aliases`](https://typesense.org/docs/0.24.1/api/collection-alias.html)
- [ ] [`Synonyms`](https://typesense.org/docs/0.24.1/api/synonyms.html)
- [ ] [`Cluster Operations`](https://typesense.org/docs/0.24.1/api/cluster-operations.html)
- [ ] Return [official Error Codes text](https://typesense.org/docs/0.24.1/api/api-errors.html)


