defmodule Raxx.Cowboy.RequestTest do
  use ExUnit.Case, async: true

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

  test "request shows correct method", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{method: "GET"}
  end

  test "request shows correct method when posting", %{port: port} do
    {:ok, _resp} = HTTPoison.post("localhost:#{port}", "")
    assert_receive %{method: "POST"}
  end

  test "request shows correct path for root", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{path: []}
  end

  test "request shows correct path for sub path", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/sub/path")
    assert_receive %{path: ["sub", "path"]}
  end

  test "request shows empty query", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/#")
    assert_receive %{query: %{}}
  end

  test "request shows correct query", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/?foo=bar")
    assert_receive %{query: %{"foo" => "bar"}}
  end

  test "request assumes maps headers", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/", [{"content-type", "unknown/stuff"}])
    assert_receive %{headers: %{"content-type" => content_type}}
    assert "unknown/stuff" == content_type
  end

end
