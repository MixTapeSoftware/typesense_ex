defmodule TypesenseEx do
  @moduledoc """
  Hydrates NodePool and Request servers (forthcoming) and their config
  """
  use Supervisor

  def start_link(config) do
    Supervisor.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl true
  def init(config) do
    children = [
      {TypesenseEx.NodePool, config},
      {TypesenseEx.Request, config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
