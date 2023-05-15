defmodule Typesense.Client do
  @moduledoc """
  Provides configuration to establish a connection with Typesense and a
  GenServer to act as a load balancer when load balancing is not handled
  by an external service.
  """

  use GenServer
  require Logger
  alias __MODULE__
  alias Typesense.TypesenseNode

  @type node_index :: integer()
  @type nodes :: [TypesenseNode.t()]
  @type next_nodes :: [TypesenseNode.t()]
  @type health_status :: TypesenseNode.health_status()
  @type error :: {:error, String.t()}
  @type from :: {pid(), tag :: term()}
  @type api_key :: String.t() | nil

  @type t :: %Client{
          api_key: api_key(),
          nodes: nodes(),
          next_nodes: next_nodes(),
          nearest_node: TypesenseNode.t() | nil,
          connection_timeout_seconds: integer(),
          healthcheck_interval_seconds: integer(),
          num_retries: integer(),
          retry_interval_seconds: float(),
          errors: [error()] | []
        }

  @type config :: %{
          api_key: api_key(),
          nodes: [TypesenseNode.config()],
          nearest_node: TypesenseNode.config() | nil,
          connection_timeout_seconds: integer(),
          healthcheck_interval_seconds: integer(),
          num_retries: integer(),
          retry_interval_seconds: float()
        }

  defstruct [
    :nodes,
    :next_nodes,
    api_key: "",
    nearest_node: nil,
    connection_timeout_seconds: 10,
    healthcheck_interval_seconds: 15,
    num_retries: 3,
    retry_interval_seconds: 0.1,
    errors: []
  ]

  # If a node has one of these statuses we return it for use in Typesense
  # requests
  @retryable_statuses [:healthy, :maybe_healthy]

  @doc """
  Mark a node as unhealthy (e.g. after a failed request)
  """
  @spec set_unhealthy(TypesenseNode.t()) :: Client.t()
  def set_unhealthy(%TypesenseNode{} = node) do
    GenServer.call(__MODULE__, {:set_health, node, :unhealthy})
  end

  @doc """
  Mark a node healthy (e.g. after recovering from a failed request)
  """
  @spec set_healthy(TypesenseNode.t()) :: Client.t()
  def set_healthy(%TypesenseNode{} = node) do
    GenServer.call(__MODULE__, {:set_health, node, :healthy})
  end

  @doc """
  Get the next retryable node in the queue

  If a node is unhealthy, it will not be returned unless the
  `healthcheck_interval_seconds` have expired.

  ## Example
  iex> node = %{host: "localhost", port: "8107", protocol: "https"}
  ...> Client.start_link(%{api_key: "123", nodes: [node]})
  ...> Client.next_node() |> TypesenseNode.to_config()
  %{host: "localhost", port: "8107", protocol: "https"}
  """
  @spec next_node() :: TypesenseNode.t()
  def next_node do
    GenServer.call(Typesense.Client, :next_node)
  end

  @doc """
  A convenience to get back the Client struct
  """
  @spec get() :: Client.t()
  def get do
    GenServer.call(Typesense.Client, :client)
  end

  @spec start_link(config()) ::
          {:ok, pid()} | :ignore | {:error, {:already_started, pid()} | term()}
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl true
  @spec init(config()) :: {:ok, Client.t()} | {:stop, any()}
  def init(config) do
    case new(config) do
      {:ok, client} ->
        {:ok, client}

      {:error, msg} ->
        {:stop, msg}
    end
  end

  @impl true
  @spec handle_call(:client, from, Client.t()) :: {:reply, Client.t(), Client.t()}
  def handle_call(:client, _from, client) do
    {:reply, client, client}
  end

  @impl true
  @spec handle_call(:next_node, from, Client.t()) :: {:reply, TypesenseNode.t(), Client.t()}
  def handle_call(
        :next_node,
        _from,
        %{nearest_node: %{health_status: health} = nearest_node} = client
      )
      when health in @retryable_statuses do
    {:reply, nearest_node, client}
  end

  @impl true
  def handle_call(:next_node, _from, %{nodes: nodes, next_nodes: next_nodes} = client)
      when length(next_nodes) == 0 do
    Logger.error("[Typesense] Couldn't Find a Healthy Node. Reverting to First Node.")

    {:reply, List.first(nodes), client}
  end

  @impl true
  def handle_call(
        :next_node,
        _from,
        %{
          nearest_node: nearest_node,
          healthcheck_interval_seconds: max_seconds,
          next_nodes: [next_node | next_nodes]
        } = client
      )
      when not is_nil(nearest_node) do
    nearest_node = maybe_mark_status_maybe_healthy(nearest_node, max_seconds)

    if retryable?(nearest_node) do
      {:reply, nearest_node, client}
    else
      {:reply, next_node, with_only_valid_next_nodes(client, next_nodes)}
    end
  end

  @impl true
  def handle_call(:next_node, _from, %{next_nodes: [next_node | next_nodes]} = client) do
    {:reply, next_node, with_only_valid_next_nodes(client, next_nodes)}
  end

  @impl true
  @spec handle_call(:set_health, from, Client.t()) :: {:reply, Client.t(), Client.t()}
  def handle_call(
        {:set_health, updatable_node, health_status},
        _from,
        client
      ) do
    new_client =
      client
      |> maybe_update_nodes_health(updatable_node, health_status)
      |> maybe_update_next_nodes_health(updatable_node, health_status)
      |> maybe_update_nearest_node_health(updatable_node, health_status)

    {:reply, new_client, new_client}
  end

  @spec maybe_update_next_nodes_health(Client.t(), TypesenseNode.t(), health_status()) ::
          Client.t()
  defp maybe_update_next_nodes_health(
         %{next_nodes: next_nodes} = client,
         updatable_node,
         health_status
       ) do
    updated_next_nodes =
      if Enum.empty?(next_nodes) do
        [set_health(updatable_node, health_status)]
      else
        maybe_set_health(next_nodes, updatable_node, health_status)
      end

    with_only_valid_next_nodes(client, updated_next_nodes)
  end

  defp maybe_update_nodes_health(%{nodes: nodes} = client, updatable_node, health_status) do
    updated_nodes = maybe_set_health(nodes, updatable_node, health_status)

    %{client | nodes: updated_nodes}
  end

  @spec maybe_set_health(nodes(), TypesenseNode.t(), health_status()) :: [TypesenseNode.t()]
  defp maybe_set_health(nodes, updatable_node, health_status) do
    Enum.reduce(nodes, [], fn node, acc ->
      if equal?(node, updatable_node) do
        [set_health(node, health_status) | acc]
      else
        [node | acc]
      end
    end)
    |> Enum.reverse()
  end

  @spec equal?(TypesenseNode.t(), TypesenseNode.t()) :: boolean()
  defp equal?(first_node, second_node) do
    TypesenseNode.to_config(first_node) == TypesenseNode.to_config(second_node)
  end

  @spec set_health(TypesenseNode.t(), health_status()) :: TypesenseNode.t()
  defp set_health(node, health_status) do
    %{node | health_status: health_status, health_set_on: DateTime.utc_now()}
  end

  @spec maybe_update_nearest_node_health(Client.t(), TypesenseNode.t(), health_status()) ::
          Client.t()
  defp maybe_update_nearest_node_health(
         %Client{nearest_node: nil} = client,
         _node,
         _health_status
       ),
       do: client

  defp maybe_update_nearest_node_health(
         %{nearest_node: nearest_node} = client,
         node,
         health_status
       ) do
    if equal?(node, nearest_node) do
      %{client | nearest_node: set_health(nearest_node, health_status)}
    else
      client
    end
  end

  @spec with_only_valid_next_nodes(Client.t(), nodes()) :: Client.t()
  defp with_only_valid_next_nodes(
         %{nodes: nodes, healthcheck_interval_seconds: max_seconds} = client,
         new_next_nodes
       ) do
    next_retryable_nodes = retryable_nodes(new_next_nodes, max_seconds)

    if length(next_retryable_nodes) > 0 do
      %{client | next_nodes: next_retryable_nodes}
    else
      %{client | next_nodes: retryable_nodes(nodes, max_seconds)}
    end
  end

  @spec retryable_nodes(nodes(), integer()) :: nodes()
  defp retryable_nodes(nodes, max_seconds) do
    nodes
    |> Enum.map(&maybe_mark_status_maybe_healthy(&1, max_seconds))
    |> Enum.filter(&retryable?/1)
  end

  @spec retryable?(TypesenseNode.t()) :: boolean()
  def retryable?(node) do
    node.health_status in @retryable_statuses
  end

  @spec maybe_mark_status_maybe_healthy(TypesenseNode.t(), integer()) :: TypesenseNode.t()
  def maybe_mark_status_maybe_healthy(node, max_seconds) do
    now = DateTime.utc_now()
    elapsed = DateTime.diff(DateTime.utc_now(), node.health_set_on)

    if node.health_status == :unhealthy and elapsed >= max_seconds do
      %{node | health_status: :maybe_healthy, health_set_on: now}
    else
      node
    end
  end

  @spec new(config()) :: {:ok, Client.t()} | error()
  defp new(config) do
    with {:ok, nodes} <- init_nodes(config),
         {:ok, nearest_node} <- init_nearest_node(config),
         :ok <- validate_api_key(config),
         config <-
           Map.merge(config, %{
             nearest_node: nearest_node,
             nodes: nodes,
             next_nodes: nodes
           }) do
      {:ok, struct(Client, config)}
    end
  end

  @spec validate_api_key(config()) :: :ok | error()
  defp validate_api_key(%{api_key: api_key}) when is_binary(api_key), do: :ok

  defp validate_api_key(_config_) do
    {:error, "Configuration Missing API Key"}
  end

  @spec init_nearest_node(config()) :: {:ok, TypesenseNode.t()} | {:ok, nil} | error()

  defp init_nearest_node(config) when not is_map_key(config, :nearest_node), do: {:ok, nil}

  defp init_nearest_node(%{nearest_node: nil}), do: {:ok, nil}

  defp init_nearest_node(%{nearest_node: nearest_node_params}) do
    if TypesenseNode.valid?(nearest_node_params) do
      {:ok, TypesenseNode.new(nearest_node_params)}
    else
      {:error, "Invalid Nearest Node Specification"}
    end
  end

  @spec init_nodes(config()) :: {:ok, nodes()} | {:error, String.t()}
  defp init_nodes(%{nodes: nodes}) when length(nodes) == 0 do
    {:error, "Configuration Contains an Empty Node List"}
  end

  defp init_nodes(%{nodes: nodes}) when not is_list(nodes) do
    {:error, "Configuration Nodes Not a List"}
  end

  defp init_nodes(map) when map == %{} do
    {:error, "Configuration Missing Nodes"}
  end

  defp init_nodes(%{nodes: nodes}) do
    nodes_valid? = Enum.all?(nodes, &TypesenseNode.valid?/1)

    err_msg = "One or More Node Configurations Missing Data"

    if nodes_valid? do
      {:ok, Enum.map(nodes, &TypesenseNode.new/1)}
    else
      {:error, err_msg}
    end
  end

  defp init_nodes(_config_without_nodes) do
    {:error, "Configuration Missing Node List"}
  end
end
