defmodule ServerSentEvents do
  use Application

  def start(_type, _args) do
    routes = [
      {:_, Raxx.Adapters.Cowboy.Handler, {ServerSentEvents.Router, %{}}}
    ]

    dispatch = :cowboy_router.compile([{:_, routes}])

    opts = [port: 8080]
    env = [dispatch: dispatch]

    # Don't forget can set any name
    {:ok, _pid} = :cowboy.start_http(:http, 100, opts, [env: env])
  end
end
