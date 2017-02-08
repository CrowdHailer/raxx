defmodule Ace.HTTP.Mixfile do
  use Mix.Project

  def project do
    [app: :ace_http,
     version: "0.1.2",
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
      {:raxx, "~> 0.10.1"},
      {:http_status, "~> 0.2.0"},
      {:ace, "0.7.0"},
      {:raxx_verify, path: "../raxx_verify", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    HTTP Server built on top of Ace TCP connection manager
    """
  end

  defp package do
    [
     maintainers: ["Peter Saxton"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/CrowdHailer/raxx/tree/master/ace_http"}]
  end
end
