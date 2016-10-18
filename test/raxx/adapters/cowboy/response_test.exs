defmodule Raxx.Cowboy.ResponseTest do
  use Raxx.Adapters.ResponseCase

  setup %{case: case, test: test} do
    name = {case, test}
    routes = [
      {:_, Raxx.Adapters.Cowboy.Handler, {__MODULE__, %{target: self()}}}
    ]
    dispatch = :cowboy_router.compile([{:_, routes}])
    env = [dispatch: dispatch]
    {:ok, _pid} = :cowboy.start_http(name, 2, [port: 0], [env: env])
    {:ok, %{port: :ranch.get_port(name)}}
  end

end
