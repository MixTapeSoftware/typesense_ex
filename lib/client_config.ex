defmodule TypesenseEx.ClientConfig do
  @moduledoc """
  Validates configuration params
  """

  # errors is just an internal convenience
  # we return a traditional {:error, errors} tuple
  # on validation
  @derive {Inspect, except: [:errors]}

  alias __MODULE__
  alias TypesenseEx.Node

  # @typedoc """
  # Configuration Params

  # ## Fields

  #   * `nearest_node` - (optional) node configuration for geographically nearest node (for optimizing network latency) . Type: `Node.config`
  #   * `api_key` - (recommended) Typesense API key. Type: `String`
  #   * `nodes` - List of Typesense Node Configurations. Type: `[Node.config]`
  #   * `connection_timeout_seconds` - [defaults to 10] Establishes how long Typesense should wait before retrying a request to a typesense node after timing out. Type: `integer`
  #   * `healthcheck_interval_seconds` - [defaults to 15] The number of seconds to wait before resuming requests for a node after it has been marked unhealthy. Type: `integer`
  #   * `num_retries` - [defaults to 3] The number of retry attempts that should be made before marking a node unhealthy. Type: `integer`
  #   * `retry_interval_seconds` - [defaults to 0.1] The number of seconds to wait between retries. Type: `float`
  # """

  @typedoc "Whether or not a validation has failed"
  @type validation_response :: :ok | {:error, String.t()}
  @typedoc "A list of Node Configurations"
  @type typesense_nodes :: [Node.config()]
  @typedoc "A Typesense API key"
  @type api_key :: String.t() | nil
  @typedoc "Maybe a list of error messages"
  @type errors :: [String.t()] | []
  @typedoc "A structure used to collect node config errors"
  @type node_validation :: {Node.config(), errors}

  defstruct [
    :nodes,
    api_key: "",
    nearest_node: nil,
    connection_timeout_seconds: 10,
    healthcheck_interval_seconds: 15,
    num_retries: 3,
    retry_interval_seconds: 0.1,
    errors: []
  ]

  @type t :: %ClientConfig{
          nearest_node: Node.config() | %{},
          nodes: typesense_nodes,
          api_key: api_key,
          connection_timeout_seconds: integer(),
          healthcheck_interval_seconds: integer(),
          num_retries: integer(),
          retry_interval_seconds: float(),
          errors: errors
        }

  @type config_params :: %{
          optional(:nearest_node) => Node.config(),
          nodes: typesense_nodes,
          api_key: api_key,
          connection_timeout_seconds: integer(),
          healthcheck_interval_seconds: integer(),
          num_retries: integer(),
          retry_interval_seconds: float()
        }

  @spec new(config_params | nil) :: t

  def new(nil) do
    {:error, "Config cannot be nil"}
  end

  def new(config) do
    struct(ClientConfig, config)
  end

  @spec validate(t) :: t
  def validate(%ClientConfig{} = config) do
    result =
      config
      |> validate_nodes()
      |> validate_nearest_node()
      |> validate_api_key()

    case result.errors do
      [] ->
        {:ok, result}

      errors ->
        {:error, errors}
    end
  end

  @spec validate_api_key(t()) :: t
  defp validate_api_key(%{api_key: api_key} = config) when is_binary(api_key), do: config

  defp validate_api_key(%{errors: errors} = config) do
    %ClientConfig{config | errors: ["Configuration Missing API Key" | errors]}
  end

  defp validate_nearest_node(%{nearest_node: nearest_node_config, errors: errors} = config) do
    case node_errors(nearest_node_config) do
      [] ->
        config

      node_errors ->
        %ClientConfig{config | errors: node_errors ++ errors}
    end
  end

  defp validate_nodes(%ClientConfig{nodes: nodes, errors: errors} = config)
       when not is_list(nodes) do
    msg = "Expected nodes to be a list but got '#{inspect(nodes)}'"
    %ClientConfig{config | errors: [msg | errors]}
  end

  defp validate_nodes(%ClientConfig{nodes: nodes, errors: errors} = config) do
    invalid_nodes =
      nodes
      |> Enum.map(&node_errors/1)
      |> Enum.reject(&Enum.empty?/1)
      |> List.flatten()

    case invalid_nodes do
      [] ->
        config

      node_errors ->
        %ClientConfig{config | errors: node_errors ++ errors}
    end
  end

  defp node_errors(nil), do: []

  @spec node_errors(Node.config()) :: errors()
  defp node_errors(node_config) when is_map(node_config) do
    {_node_config, errors} =
      {node_config, []}
      |> present?(:host)
      |> present?(:port)
      |> contains?(:protocol, ["http", "https"])
      |> integer?(:port)

    errors
  end

  @spec integer?(node_validation(), atom()) :: node_validation()
  def integer?({config, errors}, key) do
    case Integer.parse(Map.get(config, key)) do
      {_value, ""} -> {config, errors}
      {_value, extra} -> {config, ["Invalid characters for #{key}: '#{extra}'" | errors]}
      :error -> {config, ["#{key} is not an integer" | errors]}
    end
  end

  @spec contains?(node_validation(), atom(), [String.t()]) :: node_validation()
  def contains?({config, errors}, key, valid_values) do
    if Map.get(config, key) in valid_values do
      {config, errors}
    else
      values = Enum.join(valid_values, ", ")
      {config, ["#{key} not in acceptable values [#{values}]" | errors]}
    end
  end

  @spec present?(node_validation(), atom()) :: node_validation()
  defp present?({config, errors}, key) do
    case Map.get(config, key) do
      nil ->
        all_keys = Map.keys(config) |> Enum.join(", ")
        {config, ["Node Config Missing #{key}. Keys Found: #{all_keys}" | errors]}

      _value ->
        {config, errors}
    end
  end
end
