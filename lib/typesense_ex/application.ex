defmodule TypesenseEx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  use Application
  @impl true

  def start(_type, _args) do
    config = Application.get_env(:typesense_ex, :client_config)

    children = [
      {Registry, keys: :unique, name: TypesenseEx.NodeRegistry},
      {TypesenseEx.NodePool, config}
    ]

    opts = [strategy: :one_for_one, name: TypesenseEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
