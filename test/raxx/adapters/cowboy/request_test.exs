defmodule Raxx.Cowboy.RequestTest do
  use Raxx.Adapters.RequestCase

  setup %{case: case, test: test} do
    name = {case, test}
    routes = [
      {:_, Raxx.Adapters.Cowboy.Handler, {Raxx.TestSupport.Forwarder, %{target: self()}}}
    ]
    dispatch = :cowboy_router.compile([{:_, routes}])
    env = [dispatch: dispatch]
    {:ok, _pid} = :cowboy.start_http(name, 2, [port: 0], [env: env])
    {:ok, %{port: :ranch.get_port(name)}}
  end

  test "request shows correct host", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{host: "localhost"}
  end

  test "request shows correct port", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{port: ^port}
  end


end
