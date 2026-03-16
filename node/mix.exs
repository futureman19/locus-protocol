defmodule Locus.MixProject do
  use Mix.Project

  def project do
    [
      app: :locus,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Locus, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # BSV SDK for blockchain interaction
      {:bsv_sdk, "~> 1.1.0"},

      # JSON encoding/decoding
      {:jason, "~> 1.4"},

      # MessagePack for binary payloads
      {:msgpax, "~> 2.4"},

      # H3 hexagonal grid indexing
      {:h3, "~> 3.0", optional: true},

      # gRPC for local API (future)
      {:grpc, "~> 0.7", optional: true},

      # Testing
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
