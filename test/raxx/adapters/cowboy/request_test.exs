defmodule Raxx.Adapters.Cowboy.RequestTest do
  use Raxx.Adapters.RequestCase

  case Application.ensure_all_started(:cowboy) do
    {:ok, _} ->
      :ok
    {:error, {:cowboy, _}} ->
      raise "could not start the cowboy application. Please ensure it is listed " <>
            "as a dependency both in deps and application in your mix.exs"
  end

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

end
