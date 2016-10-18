defmodule Raxx.Ace.RequestTest do
  use Raxx.Adapters.RequestCase

  setup %{case: case, test: test} do
    raxx_app = {Raxx.TestSupport.Forwarder, %{target: self()}}
    {:ok, endpoint} = Ace.TCP.start_link({Raxx.Adapters.Ace.Handler, raxx_app}, port: 0)
    {:ok, port} = Ace.TCP.Endpoint.port(endpoint)
    {:ok, %{port: port}}
  end

  @tag :skip
  test "request shows correct host", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{host: "localhost"}
  end

  @tag :skip
  # currently only the peer port is available.
  test "request shows correct port", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{port: ^port}
  end

  @tag :skip
  test "request assumes maps headers", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/", [{"content-type", "unknown/stuff"}])
    assert_receive %{headers: %{"content-type" => content_type}}
    assert "unknown/stuff" == content_type
  end

end
