defmodule CowboyExample do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    cert_path = Path.expand("../cert.pem", __ENV__.file |> Path.dirname)
    key_path = Path.expand("../key.pem", __ENV__.file |> Path.dirname)

    children = [
      worker(Raxx.Cowboy, [{__MODULE__, []}, [port: 8080, name: __MODULE__, cert_path: cert_path, key_path: key_path]])
    ]

    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end

  import Raxx.Response

  def handle_request(request, _opts) do
    ok(as_string(request))
  end

  defp as_string(term) do
    (quote do: unquote(term)) |> Macro.to_string
  end
end
