defmodule TypesenseEx.Node do
  @moduledoc """
  A typesense node
  """
  alias __MODULE__

  @type t :: %Node{
          host: String.t(),
          port: String.t(),
          protocol: String.t()
        }

  @type config :: %{
          host: String.t(),
          port: String.t(),
          protocol: String.t()
        }
  @type error :: {:error, {String.t(), config()}}

  @type maybe_node :: {:ok, t} | error()

  defstruct [
    :host,
    :port,
    :protocol
  ]

  @spec new(config) :: t()
  def new(config) do
    struct(Node, config)
  end
end
