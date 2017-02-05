defmodule Raxx.Static.Mixfile do
  use Mix.Project

  def project do
    [app: :raxx_static,
     version: "0.2.0",
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
      {:raxx, "~> 0.10.0"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    Static file serving in Raxx applications.
    """
  end

  defp package do
    [
     maintainers: ["Peter Saxton"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/CrowdHailer/raxx/tree/master/raxx_static"}]
  end
end
