defmodule Raxx.Mixfile do
  use Mix.Project

  def project do
    [app: :raxx,
     version: "0.0.1",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     description: description,
     package: package]
  end

  def application do
    [applications: [:logger, :httpoison]]
  end

  defp deps do
    [
      {:cowboy, "1.0.4"},
      {:httpoison, "~> 0.8.0"}
    ]
  end

  defp description do
    """
    A Elixir webserver interface, for stateless HTTP.

    Raxx exists to simplify handling the HTTP request-response cycle.
    It deliberately does not handle other communication styles that are part of the modern web.
    """
  end

  defp package do
    [
     maintainers: ["Peter Saxton"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/crowdhailer/raxx"}]
  end
end
