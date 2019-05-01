defmodule RaxxSession.MixProject do
  use Mix.Project

  def project do
    [
      app: :raxx_session,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:raxx, "~> 1.0"},
      {:cookie, "~> 0.1.1"},
      {:plug_crypto, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
