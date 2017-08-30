defmodule Raxx.Mixfile do
  use Mix.Project

  def project do
    [app: :raxx,
     version: "0.11.1",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description(),
     docs: [extras: ["README.md"], main: "Raxx"],
     package: package()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:mime, "~> 1.0"},
      {:plug, "~> 1.2"}, # DEBT remove; currently used for query strings etc
      {:http_status, "~> 0.2"},
      {:ex_doc, ">= 0.0.0", only: :dev},
    ]
  end

  defp description do
    """
    Streaming HTTP interface for Elixir.

    Including a simple and powerful library for building HTTP clients and web applications.
    """
  end

  defp package do
    [
     maintainers: ["Peter Saxton"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/crowdhailer/raxx"}]
  end
end
