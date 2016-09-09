defmodule CowboyExample do
  use Application

  def start(_type, _args) do
    routes = [
      {:_, Raxx.Adapters.Cowboy.Handler, {__MODULE__, []}}
    ]

    dispatch = :cowboy_router.compile([{:_, routes}])

    opts = [port: 8080]
    env = [dispatch: dispatch]

    # Don't forget can set any name
    {:ok, _pid} = :cowboy.start_http(:http, 100, opts, [env: env])
  end

  import Raxx.Response

  def handle_request(request, _opts) do
    ok(as_string(request))
  end

  defp as_string(term) do
    (quote do: unquote(term)) |> Macro.to_string
  end
end
