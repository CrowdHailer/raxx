defmodule Raxx.Verify.Mixfile do
  use Mix.Project

  def project do
    [app: :raxx_verify,
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
      {:httpoison, "~> 0.8.0"},
      {:raxx_server_sent_events, ">= 0.0.0", path: "../raxx_server_sent_events"}
    ]
  end
end
