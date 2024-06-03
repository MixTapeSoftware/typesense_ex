defmodule TypesenseEx.Node do
  @moduledoc """
  A typesense node
  """
  alias __MODULE__

  @type from :: {pid(), tag :: term()}
  @type seconds_removed :: float()

  @type t :: %Node{
          id: number(),
          host: String.t(),
          port: String.t(),
          protocol: String.t(),
          marked_unhealthy_at: DateTime.t(),
          last_used: DateTime.t(),
          is_nearest: boolean()
        }

  @type config :: %{
          host: String.t(),
          port: String.t(),
          protocol: String.t(),
          is_nearest: boolean()
        }
  @type error :: {:error, {String.t(), config()}}

  @type maybe_node :: {:ok, t} | error()

  defstruct [
    :id,
    :host,
    :port,
    :protocol,
    is_nearest: false,
    marked_unhealthy_at: nil,
    last_used: DateTime.utc_now()
  ]

  @spec new(config) :: t()
  def new(config) do
    last_used = DateTime.utc_now()
    %Node{struct(Node, config) | last_used: last_used}
  end
end
