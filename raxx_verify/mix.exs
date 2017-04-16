defmodule Raxx.Verify.Mixfile do
  use Mix.Project

  def project do
    [app: :raxx_verify,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description(),
     package: package()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:httpoison, "~> 0.8"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    Cowboy adapter for the Raxx webserver interface
    """
  end

  defp package do
    [
     maintainers: ["Peter Saxton"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/CrowdHailer/raxx/tree/master/raxx_cowboy"}]
  end
end
