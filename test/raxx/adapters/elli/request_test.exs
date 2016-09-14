defmodule Raxx.Elli.RequestTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, _pid} = :elli.start_link [
      callback: Raxx.Adapters.Elli.Handler,
      callback_args: {Raxx.TestSupport.Forwarder, %{target: self()}},
      port: 2020]
    {:ok, %{port: 2020}}
  end

  test "request shows correct method", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{method: "GET"}
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
    assert_receive %{headers: %{"Content-Type" => content_type}}
    assert "unknown/stuff" == content_type
  end

end
