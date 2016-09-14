defmodule Raxx.Cowboy.StreamingTest do
  use ExUnit.Case, async: true

  setup %{case: case, test: test} do
    name = {case, test}
    routes = [
      {:_, Raxx.Adapters.Cowboy.Handler, {Raxx.TestSupport.Streaming, %{chunks: ["a", "b", "c"]}}}
    ]
    dispatch = :cowboy_router.compile([{:_, routes}])
    env = [dispatch: dispatch]
    {:ok, _pid} = :cowboy.start_http(name, 2, [port: 0], [env: env])
    {:ok, %{port: :ranch.get_port(name)}}
  end

  test "request shows correct host", %{port: port} do
    headers = %{"accept" => "text/event-stream",
      "cache-control" => "no-cache",
      "connection" => "keep-alive"}
    {:ok, %{id: ref}} = HTTPoison.get("localhost:#{port}", headers, stream_to: self)
    assert_receive %{chunk: "a"}, 1000
    assert_receive %{chunk: "b"}, 1000
    assert_receive %{chunk: "c"}, 1000
  end
end
