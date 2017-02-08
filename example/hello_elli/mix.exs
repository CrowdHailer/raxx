defmodule HelloElli.Mixfile do
  use Mix.Project

  def project do
    [app: :hello_elli,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger],
     mod: {HelloElli, []}]
  end

  defp deps do
    [
      {:elli, "~> 1.0"},
      {:raxx_elli, ">= 0.0.0", path: "../../raxx_elli"},
    ]
  end
end
