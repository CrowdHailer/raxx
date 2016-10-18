defmodule Raxx.Elli.RequestTest do
  use Raxx.Adapters.RequestCase

  setup do
    {:ok, _pid} = :elli.start_link [
      callback: Raxx.Adapters.Elli.Handler,
      callback_args: {Raxx.TestSupport.Forwarder, %{target: self()}},
      port: 2020]
    {:ok, %{port: 2020}}
  end

  test "request assumes maps headers", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/", [{"content-type", "unknown/stuff"}])
    assert_receive %{headers: %{"Content-Type" => content_type}}
    assert "unknown/stuff" == content_type
  end

end
