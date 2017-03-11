defmodule Raxx.Cowboy do
  def start_link(raxx_app, server_options) do
    dispatch = dispatch_for(raxx_app)
    name = Keyword.get(server_options, :name, __MODULE__)
    acceptors = Keyword.get(server_options, :acceptors, 100)
    port = Keyword.get(server_options, :port)
    :ranch_listener_sup.start_link(
      name,
      acceptors,
      :ranch_tcp,
      [port: port],
      :cowboy_protocol,
      [env: [dispatch: dispatch]]
    )
  end

  defp dispatch_for({handler, config}) do
    routes = [
      {:_, Raxx.Cowboy.Handler, {handler, config}}
    ]
    dispatch = :cowboy_router.compile([{:_, routes}])
  end
end
