defmodule CowboyExample do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Raxx.Cowboy, [{__MODULE__, []}, [port: 8080, name: __MODULE__]])
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
