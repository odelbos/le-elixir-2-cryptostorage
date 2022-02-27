defmodule CryptoStorage.MixProject do
  use Mix.Project

  def project do
    [
      app: :crypto_storage,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {CryptoStorage.Application, []}
    ]
  end

  defp deps do
    [
      {:cowboy, "~> 2.9"},
      {:plug_cowboy, "~> 2.5"},
      {:jason, "~> 1.3"},
      {:crypto_blocks, git: "https://github.com/odelbos/le-elixir-1-cryptoblocks.git"}
    ]
  end
end
