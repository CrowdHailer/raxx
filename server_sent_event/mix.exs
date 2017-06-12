defmodule ServerSentEvent.Mixfile do
  use Mix.Project

  def project do
    [app: :server_sent_event,
     version: "0.2.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description(),
     docs: [extras: ["README.md"], main: "ServerSentEvent"],
     package: package()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    Push updates to Web clients over HTTP or using dedicated server-push protocols.
    """
  end

  defp package do
    [
     files: ["lib", "mix.exs", "README*"],
     maintainers: ["Peter Saxton"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/CrowdHailer/raxx/tree/master/server_sent_event"}]
  end
end
