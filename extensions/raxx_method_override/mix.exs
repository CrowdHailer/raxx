defmodule RaxxMethodOverride.MixProject do
  use Mix.Project

  def project do
    [
      app: :raxx_method_override,
      version: "0.4.1",
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
      {:raxx, "~> 0.18.0 or ~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    Override a requests POST method with the method defined in the `_method` parameter.
    """
  end

  defp package do
    [
      maintainers: ["Peter Saxton"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" =>
          "https://github.com/crowdhailer/raxx/tree/master/extensions/raxx_method_override"
      }
    ]
  end
end
