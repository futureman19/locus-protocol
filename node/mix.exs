defmodule Locus.MixProject do
  use Mix.Project

  def project do
    [
      app: :locus,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Locus, []}
    ]
  end

  defp deps do
    [
      {:bsv_sdk, "~> 1.1.0"},
      {:jason, "~> 1.4"}
    ]
  end
end
