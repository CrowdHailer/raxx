defmodule CookieManipulation.Mixfile do
  use Mix.Project

  def project do
    [app: :cookie_manipulation,
     version: "0.0.1",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Make sure to add cowboy the list of running applications
  def application do
    [applications: [:logger, :cowboy],
     mod: {CookieManipulation, []}]
  end

  defp deps do
    [
      {:cowboy, "1.0.4"},
      {:raxx, ">= 0.0.0", path: "../../"}
    ]
  end
end
