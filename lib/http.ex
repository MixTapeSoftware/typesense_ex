defmodule Typesense.Http do
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

  @callback client(middleware(), any()) :: Tesla.Client.t()
  # @callback request([option]) :: Tesla.Env.result()

  def client(middleware, adapter), do: impl().client(middleware, adapter)

  def request(options) do
    configured_client().request(options)
  end

  defp configured_client() do
    adapter = Application.get_env(:typesense, :adapter, Tesla.Adapter.Hackney)
    middleware = Application.get_env(:typesense, :middleware, [])

    impl().client(middleware, adapter)
  end

  defp impl do
    Application.get_env(:typesense, :http_library, Tesla)
  end
end
