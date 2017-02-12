defmodule Raxx.Mixfile do
  use Mix.Project

  def project do
    [app: :raxx,
     version: "0.10.3",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     description: description,
     docs: [extras: ["README.md"], main: "readme"],
     package: package]
  end

  def application do
    [applications: [:logger, :mime]]
  end

  defp deps do
    [
      {:mime, "~> 1.0"},
      {:plug, "~> 1.2.2"}, # DEBT remove; currently used for query strings etc
      {:http_status, "~> 0.2"},
      {:ex_doc, ">= 0.0.0", only: :dev},
    ]
  end

  defp description do
    """
    Pure interface for webservers and frameworks.

    Including a powerful tools library for building refined web applications
    """
  end

  defp package do
    [
     maintainers: ["Peter Saxton"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/crowdhailer/raxx"}]
  end
end
