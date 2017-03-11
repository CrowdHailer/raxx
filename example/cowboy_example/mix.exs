defmodule CowboyExample.Mixfile do
  use Mix.Project

  def project do
    [app: :cowboy_example,
     version: "0.0.1",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Make sure to add cowboy the list of running applications
  def application do
    [applications: [:logger, :cowboy],
     mod: {CowboyExample, []}]
  end

  defp deps do
    [
      {:raxx_cowboy, path: "../../raxx_cowboy"}
    ]
  end
end
