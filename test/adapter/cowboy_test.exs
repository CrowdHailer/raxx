defmodule Forwarder do
  import Raxx.Response
  def call(request, pid) do
    send(pid, request)
    ok("done")
  end
end
defmodule Raxx.CowboyTest do
  use ExUnit.Case, async: true

  setup_all do
    {:ok, agent} = Agent.start_link(fn -> 1 end)
    case Application.ensure_all_started(:cowboy) do
      {:ok, _} ->
        {:ok, %{agent: agent}}
      {:error, {:cowboy, _}} ->
        raise "could not start the cowboy application. Please ensure it is listed " <>
              "as a dependency both in deps and application in your mix.exs"
    end
  end

  setup %{agent: agent} do
    id = Agent.get_and_update(agent, fn (i) -> {i, i + 1}end)
    {:ok, %{port: 10_000 + id}}
  end

  def raxx_up(port) do
    routes = [
      {:_, Raxx.Adapters.Cowboy.Handler, {Forwarder, self}}
    ]
    dispatch = :cowboy_router.compile([{:_, routes}])
    env = [dispatch: dispatch]
    :cowboy.start_http(
      :"test_on_#{port}",
      2,
      [port: port],
      [env: env]
    )
  end

  test "other", %{port: port} do
    {:ok, _pid} = raxx_up(port)
    assert true
  end

  test "setup cowboy", %{port: port} do
    {:ok, _pid} = raxx_up(port)
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{host: "localhost"}
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{port: ^port}
    # METHODS
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{method: "GET"}
    {:ok, _resp} = HTTPoison.post("localhost:#{port}", "")
    assert_receive %{method: "POST"}
    # PATH
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{path: []}
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/")
    assert_receive %{path: []}
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/sub/path")
    assert_receive %{path: ["sub", "path"]}
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/?")
    assert_receive %{path: []}
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/?#")
    assert_receive %{path: []}
    # QUERY
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{query: %{}}
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/?")
    assert_receive %{query: %{}}
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/?foo=bar")
    assert_receive %{query: %{"foo" => "bar"}}
    # TODO nested queries
    # {:ok, _resp} = HTTPoison.get("localhost:10001/?foo[]=1&foo[]=2")
    # assert_receive %{query: %{"foo" => ["1", "2"]}}
    # TODO invalid queries
    # {:ok, _resp} = HTTPoison.get("localhost:10001/?some-search")
    # assert_receive %{query: "?some-search"
  end
end
