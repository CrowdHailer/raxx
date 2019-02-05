defmodule RaxxLogger.MixProject do
  use Mix.Project

  def project do
    [
      app: :raxx_logger,
      version: "0.2.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:raxx, "~> 0.17.5"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    Middleware for basic logging in Raxx services.
    """
  end

  defp package do
    [
      maintainers: ["Peter Saxton"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => "https://github.com/crowdhailer/raxx/tree/master/extensions/raxx_logger"
      }
    ]
  end
end
