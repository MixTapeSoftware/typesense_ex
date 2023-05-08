defmodule TypeSense.Client do
  @moduledoc """
  Provides configuration to establish a connection with Typesense
  """

  alias __MODULE__

  @type typesense_node :: %{
          host: String.t(),
          port: String.t(),
          protocol: String.t()
        }

  @type t :: %{
          api_key: String.t(),
          nodes: [typesense_node],
          nearest_node: typesense_node,
          connection_timeout_seconds: integer(),
          healthcheck_interval_seconds: integer(),
          num_retries: integer(),
          retry_interval_seconds: float()
        }

  defstruct api_key: "",
            nodes: [],
            nearest_node: nil,
            connection_timeout_seconds: 10,
            healthcheck_interval_seconds: 15,
            num_retries: 3,
            retry_interval_seconds: 0.1

  @doc """
  Accepts a raw configuration map and returns a Typesense Client.

  ## Examples
    iex> {:ok, _client} = Client.new(%{nodes: [%{host: "localhost", port: "8180", protocol: "http"}]})
  """
  @spec new(map()) :: {:ok, t} | {:error, String.t()}
  def new(config) do
    struct(Client, config) |> validate()
  end

  @spec(validate(t) :: {:ok, t}, {:error, String.t()})

  defp validate(%Client{nodes: nodes}) when length(nodes) == 0 do
    err_msg = """
    Missing required configuration. Ensure that nodes[][:protocol], nodes[][:host] and nodes[][:port] are set.
    """

    {:error, err_msg}
  end

  defp validate(%Client{nodes: nodes}) when not is_list(nodes) do
    err_msg = """
    The nodes configuration should contain a list of nodes.
    """

    {:error, err_msg}
  end

  defp validate(%Client{nodes: nodes} = client) do
    nodes_valid? =
      Enum.all?(nodes, fn node ->
        is_binary(node[:host]) and
          is_binary(node[:port]) and
          is_binary(node[:protocol])
      end)

    err_msg = "One or more node configurations is missing data."

    if nodes_valid? do
      {:ok, client}
    else
      {:error, err_msg}
    end
  end
end
