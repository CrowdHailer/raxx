defmodule CookieManipulation do
  use Application
  alias Raxx.Response

  def start(_type, _args) do
    routes = [
      {:_, Raxx.Adapters.Cowboy.Handler, {__MODULE__, %{}}}
    ]

    dispatch = :cowboy_router.compile([{:_, routes}])

    opts = [port: 8080]
    env = [dispatch: dispatch]

    # Don't forget can set any name
    {:ok, _pid} = :cowboy.start_http(:http, 100, opts, [env: env])
  end

  def handle_request(%{path: ["set", key, value]}, _env) do
    Response.ok("check your cookies #{value}")
    |> Response.set_cookie(key, value)
    |> Response.set_cookie("always", "on")
  end

  def handle_request(_request, _opts) do
    Response.not_found("Page not found")
  end
end
