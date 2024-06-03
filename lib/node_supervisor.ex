defmodule TypesenseEx.NodeSupervisor do
  @moduledoc """
  Supervises a pool of Typesense Nodes

  The `Pool` supervisor hydrates a set of Typesense Nodes. Typesense
  nodes can provide their configuration and may be temporarily removed from the
  requestable pool of nodes if they become unresponsive.
  """
  use Supervisor
  alias __MODULE__
  alias TypesenseEx.ClientConfig
  alias TypesenseEx.Node

  @callback next_node() :: {pid(), Node.t()}

  def start_link(config) do
    case to_config(config) do
      {:ok, config} ->
        Supervisor.start_link(NodeSupervisor, config, name: :typesense_pool)

      errors ->
        errors
    end
  end

  @impl true
  def init(config) do
    children = [
      {Registry, keys: :unique, name: TypesenseEx.NodeRegistry},
      {TypesenseEx.NodePool, config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp to_config(config) do
    config
    |> ClientConfig.new()
    |> ClientConfig.validate()
  end
end
