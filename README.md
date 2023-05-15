# Typesense

**EXPERIMENTAL / WORK IN PROGRESS**: Elixir bindings for Typesense

An elixir wrapper around the [Typesense REST Api](https://typesense.org/docs/0.24.1/api/) that comes with an Elixir-based load balancer (see below note).

This package is incomplete and will continue to change for the near future.

### Why An Elixir Load Balancer?

In many cases an external load balancer may not be present. As a result,
`Typesense` implements an Elixir-based load balancer for Typesense nodes. Nodes
that are non-responsive after configurable set of retries and health check seconds
interval are marked as healthy and will not be retried for a period of time (also
configurable). All users of the application share the Client, causing node requests
to be distributed evenly across users.

## Installation

```elixir
def deps do
  [
    {:typesense_ex, git: "git@github.com:GetAfterItApps/typesense.git", tag: "0.1"}
  ]
end
```

Add the Typsesense to your supervision tree. e.g. (Phoenix)

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
      {Typesense.Client, typsense_config()}

      # Start a worker by calling: YourApp.Worker.start_link(arg)
      # {YourApp.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: YourApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

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

Typesense.Collections.create(schema)
```

Add [Typesense Document](https://typesense.org/docs/0.24.1/api/documents.html)

```elixir
document = %{
  id: "99",
  company_name: "Jeff's Extra Toothy Kitteh Treats",
  num_employees: 1,
  country: "US"
}


Typesense.Documents.create("companies", document)
```

Search for Typesense Documents

```elixir

Typesense.Documents.search("companies", %{q: "Jeffs", query_by: "company_name"})
```
