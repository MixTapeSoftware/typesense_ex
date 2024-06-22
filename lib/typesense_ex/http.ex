defmodule TypesenseEx.Http do
  @moduledoc """
  A wrapper around Tesla to make the http library configurable
  """

  @type option() ::
          {:method, Tesla.Env.method()}
          | {:url, Tesla.Env.url()}
          | {:query, Tesla.Env.query()}
          | {:headers, Tesla.Env.headers()}
          | {:body, Tesla.Env.body()}
          | {:opts, Tesla.Env.opts()}

  @type middleware :: [{any(), any()}] | []

  @callback client(middleware()) :: Tesla.Client.t()
  @callback request(Tesla.Client.t(), [option]) :: {:ok, Tesla.Env.t()}

  def client(middleware), do: impl().client(middleware)

  def request(client, options), do: impl().request(client, options)

  def execute(options, timeout) do
    impl().request(configured_client(timeout), options)
  end

  def configured_client(timeout) do
    timeout_middleware = {Tesla.Middleware.Timeout, timeout: timeout}

    middleware = [timeout_middleware | Application.get_env(:typesense_ex, :middleware, [])]

    client(middleware)
  end

  def impl do
    Application.get_env(:typesense_ex, :http_library, Tesla)
  end
end
