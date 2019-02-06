defmodule RaxxView.MixProject do
  use Mix.Project

  def project do
    [
      app: :raxx_view,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      docs: [extras: ["README.md"], main: "readme"],
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
      {:raxx, "~> 0.17.6"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    Generate HTML views from `.eex` template files for Raxx web applications.
    """
  end

  defp package do
    [
      maintainers: ["Peter Saxton"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => "https://github.com/crowdhailer/raxx/tree/master/extensions/raxx_view"
      }
    ]
  end
end
