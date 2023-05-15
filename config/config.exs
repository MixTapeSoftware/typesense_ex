import Config

config :logger, level: :debug

config :typesense_ex,
  middleware: []

if Mix.env() == :test do
  config :typesense_ex, adapter: Tesla.Adapter.Hackney
end
