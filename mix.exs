defmodule Raxx.Mixfile do
  use Mix.Project

  def project do
    [
      app: :raxx,
      version: "0.14.0",
      elixir: "~> 1.5",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      docs: [extras: ["README.md"], main: "Raxx"],
      package: package()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:http_status, "~> 0.2"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    Interface for HTTP webservers, frameworks and clients.
    """
  end

  defp package do
    [
      maintainers: ["Peter Saxton"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/crowdhailer/raxx"}
    ]
  end
end
