defmodule Raxx.Mixfile do
  use Mix.Project

  def project do
    [
      app: :raxx,
      version: "0.14.7",
      elixir: "~> 1.5",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_options: [
        warnings_as_errors: true
      ],
      description: description(),
      docs: [extras: ["README.md"], main: "readme"],
      package: package()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},
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
