# TypesenseEx

(**EXPERIMENTAL / WORK IN PROGRESS**)

- Elixir bindings for the [Typesense REST Api](https://typesense.org/docs/0.24.1/api/)
- A round-robbin load balancer for Typesense Nodes

## Installation and Configuration

### Install Typesense

Either [Install typesense locally](https://typesense.org/docs/guide/install-typesense.html) or
use the hosted version, [typesense cloud](https://cloud.typesense.org/).

**Example** of a docker-compose typesense instance with an api key configured:

```docker

services:
  typesense:
    image: typesense/typesense:0.26.0
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
    {:typesense_ex, git: "https://github.com/MixTapeSoftware/typesense_ex.git"}
  ]
end
```

Add the Typesense to your supervision tree:

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
      {TypesenseEx, typesense_config()},

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

### Configuration

TypesenseEx is configurable at application start. Configuration may also be updated in a running service (e.g. to dynamically add/remove Typesense nodes as they come online or have been terminated).

**Configuration Options**

| Name                 | Description                                                                                                                                                 |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | --- |
| nodes                | (optional) A list of typesense node configurations                                                                                                          |
| nearest_node         | (optional) A Typesense cloud [Search Delivery Network](https://typesense.org/docs/guide/typesense-cloud/search-delivery-network.html#how-it-helps) feature. |
| api_key              | (optional but recommended) A string representing the configured typesense api key (e.g. above it's "`MY_TYPESENSE_API_KEY`")                                |
| connection_timeout   | [defaults to 10,000] Establishes how long in *milli*seconds Typesense should wait before retrying a request to a typesense node after timing out            |
| num_retries          | [defaults to 3] The number of retry attempts that should be made before marking a node unhealthy                                                            |
| retry_interval       | [defaults to 100 / .10 second] The number of *milli*seconds to wait between retries                                                                         |
| healthcheck_interval | [defaults to 15,000 / 15 seconds] The number of *milli*seconds to wait before resuming requests for a node after it has been marked unhealthy               | `   |
