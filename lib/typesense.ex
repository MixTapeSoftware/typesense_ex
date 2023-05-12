defmodule Typesense do
  @moduledoc """
  Manages a client instance. The client keeps track of Typesense
  nodes and their health. The supervisor restarts the client
  if it dies.
  """
  use Supervisor

  def start_link(config) do
    Supervisor.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl true
  def init(config) do
    children = [
      {Typesense.Client, config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
