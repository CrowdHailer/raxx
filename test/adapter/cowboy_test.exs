defmodule Forwarder do
  import Raxx.Response
  def call(request, pid) do
    send(pid, request)
    ok("done")
  end
end
defmodule Raxx.CowboyTest do
  use ExUnit.Case

  test "setup cowboy" do
    case Application.ensure_all_started(:cowboy) do
      {:ok, _} ->
        :ok
      {:error, {:cowboy, _}} ->
        raise "could not start the cowboy application. Please ensure it is listed " <>
              "as a dependency both in deps and application in your mix.exs"
    end
    routes = [
      {:_, Raxx.Adapters.Cowboy.Handler, {Forwarder, self, []}}
    ]
    dispatch = :cowboy_router.compile([{:_, routes}])
    env = [dispatch: dispatch]
    {:ok, _pid} = :cowboy.start_http(
      :http,
      2,
      [port: 10001],
      [env: env]
    )
    # Server
    {:ok, _resp} = HTTPoison.get("localhost:10001")
    assert_receive %{host: "localhost"}
    {:ok, _resp} = HTTPoison.get("localhost:10001")
    assert_receive %{port: 10001}
    # METHODS
    {:ok, _resp} = HTTPoison.get("localhost:10001")
    assert_receive %{method: "GET"}
    {:ok, _resp} = HTTPoison.post("localhost:10001", "")
    assert_receive %{method: "POST"}
    # PATH
    {:ok, _resp} = HTTPoison.get("localhost:10001")
    assert_receive %{path: []}
    {:ok, _resp} = HTTPoison.get("localhost:10001/")
    assert_receive %{path: []}
    {:ok, _resp} = HTTPoison.get("localhost:10001/sub/path")
    assert_receive %{path: ["sub", "path"]}
    {:ok, _resp} = HTTPoison.get("localhost:10001/?")
    assert_receive %{path: []}
    {:ok, _resp} = HTTPoison.get("localhost:10001/?#")
    assert_receive %{path: []}
    # QUERY
    {:ok, _resp} = HTTPoison.get("localhost:10001")
    assert_receive %{query: %{}}
    {:ok, _resp} = HTTPoison.get("localhost:10001/?")
    assert_receive %{query: %{}}
    {:ok, _resp} = HTTPoison.get("localhost:10001/?foo=bar")
    assert_receive %{query: %{"foo" => "bar"}}
    # TODO nested queries
    # {:ok, _resp} = HTTPoison.get("localhost:10001/?foo[]=1&foo[]=2")
    # assert_receive %{query: %{"foo" => ["1", "2"]}}
    # TODO invalid queries
    # {:ok, _resp} = HTTPoison.get("localhost:10001/?some-search")
    # assert_receive %{query: "?some-search"
  end
end
