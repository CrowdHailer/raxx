defmodule Raxx.Elli.Mixfile do
  use Mix.Project

  def project do
    [app: :raxx_elli,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description(),
     package: package()]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:raxx, "~> 0.8.2"},
      {:elli, "~> 1.0"},
      {:raxx_verify, path: "../raxx_verify", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    Elli adapter for the Raxx webserver interface
    """
  end

  defp package do
    [
     maintainers: ["Peter Saxton"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/CrowdHailer/raxx/tree/master/raxx_elli"}]
  end
end
