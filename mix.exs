defmodule Raxx.Mixfile do
  use Mix.Project

  def project do
    [app: :raxx,
     version: "0.4.2",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     description: description,
     docs: [extras: ["README.md"], main: "readme"],
     package: package]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:cowboy, "1.0.4", only: :test},
      {:ace, "0.7.0", only: :test},
      {:elli, "~> 1.0", only: :test},
      {:httpoison, "~> 0.8.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    A Elixir webserver interface.

    1. An interface specification for Elixir webservers and Elixir application.
    2. A set of tools to help develop Raxx-compliant web applications
    """
  end

  defp package do
    [
     maintainers: ["Peter Saxton"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/crowdhailer/raxx"}]
  end
end
