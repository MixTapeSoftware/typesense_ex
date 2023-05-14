defmodule Typesense.MixProject do
  use Mix.Project

  def project do
    [
      app: :typesense,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.6.1"},
      {:hackney, "~> 1.17", only: [:dev, :test]},
      {:jason, "~> 1.0", only: [:dev, :test]},
      {:mox, "~> 1.0", only: :test},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false}
    ]
  end
end
