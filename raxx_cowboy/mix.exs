defmodule Raxx.Cowboy.Mixfile do
  use Mix.Project

  def project do
    [app: :raxx_cowboy,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:raxx, "~> 0.8.2"},
      {:cowboy, "1.0.4"},
      {:raxx_verify, path: "../raxx_verify", only: :test}
    ]
  end
end
