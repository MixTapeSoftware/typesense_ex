import Config

config :logger, level: :debug

config :typesense,
  middleware: []

if Mix.env() == :test do
  config :typesense, adapter: Tesla.Adapter.Hackney
end
