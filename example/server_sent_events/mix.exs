defmodule ServerSentEvents.Mixfile do
  use Mix.Project

  def project do
    [app: :server_sent_events,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger, :cowboy],
     mod: {ServerSentEvents, []}]
  end

  defp deps do
    [
      {:cowboy, "1.0.4"},
      {:raxx, ">= 0.0.0", path: "../../"}
    ]
  end
end
