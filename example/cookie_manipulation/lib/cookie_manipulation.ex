defmodule CookieManipulation do
  use Application
  alias Raxx.Response

  def start(_type, _args) do
    routes = [
      {:_, Raxx.Cowboy.Handler, {__MODULE__, %{}}}
    ]

    dispatch = :cowboy_router.compile([{:_, routes}])

    opts = [port: 8080]
    env = [dispatch: dispatch]

    # Don't forget can set any name
    {:ok, _pid} = :cowboy.start_http(:http, 100, opts, [env: env])
  end

  def handle_request(r = %{path: ["set", name, value]}, _env) do
    attributes = Enum.map(r.query, fn
      ({"expires", value}) -> {:expires, value}
      ({"max_age", value}) -> {:max_age, value}
      ({"domain", value}) -> {:domain, value}
      ({"path", value}) -> {:path, value}
      ({"secure", value}) -> {:secure, value}
      ({"http_only", "true"}) -> {:http_only, true}
      other -> IO.inspect(other)
    end)
    |> Enum.into(%{})
    Response.ok("Check your cookies")
    |> Response.set_cookie(name, value, attributes)
  end

  def handle_request(%{path: ["expire", name]}, _env) do
    Response.ok("Check your cookies")
    |> Response.expire_cookie(name)
  end

  def handle_request(_request, _opts) do
    Response.not_found("Page not found")
  end
end
