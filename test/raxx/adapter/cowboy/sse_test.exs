defmodule SSERouter do
  import Raxx.ServerSentEvents

  def call(_request, opts) do
    upgrade(opts ++ ["3"], __MODULE__)
  end

  def open(options) do
    Process.send_after(self, {:count, options}, 100)
    no_event()
  end

  def info({:count, [n | rest]}, _options) do
    Process.send_after(self, {:count, rest}, 100)
    event(n)
  end
  def info({:count, []}, _options) do
    close()
  end
end
defmodule Router do
  def call(r = %{path: [], method: "GET"}, opts) do
    SSERouter.call(r, opts)
  end
end
defmodule Raxx.Adapter.Cowboy.ServerSentEventsTest do
  use ExUnit.Case, async: true

  test "server sent events" do
    headers = %{"accept" => "text/event-stream",
      "cache-control" => "no-cache",
      "connection" => "keep-alive"}
    port = 10_100
    {:ok, _pid} = raxx_up(port, {Router, ["1", "2"]})
    {:ok, %{id: ref}} = HTTPoison.get("localhost:#{port}", headers, stream_to: self)
    assert_receive %{code: 200, id: ^ref}
    assert_receive %{headers: _headers, id: ^ref}, 1_000
    assert_receive %{chunk: _, id: ^ref}, 1_000
    assert_receive %{chunk: _, id: ^ref}, 1_000
    assert_receive %{chunk: _, id: ^ref}, 1_000
    assert_receive %{id: ^ref}, 1_000
  end

  test "server sent events with objects" do
    headers = %{"accept" => "text/event-stream",
      "cache-control" => "no-cache",
      "connection" => "keep-alive"}
    port = 10_101
    {:ok, _pid} = raxx_up(port, {Router, [%{event: "notify", data: "sup!"}]})
    {:ok, %{id: ref}} = HTTPoison.get("localhost:#{port}", headers, stream_to: self)
    assert_receive %{code: 200, id: ^ref}
    assert_receive %{headers: _headers, id: ^ref}, 1_000
    assert_receive %{chunk: message, id: ^ref}, 1_000
    assert "event: notify\ndata: sup!\n\n" == message
    assert_receive %{chunk: _, id: ^ref}, 1_000
    assert_receive %{id: ^ref}, 1_000
  end

  defp raxx_up(port, app) do
    case Application.ensure_all_started(:cowboy) do
      {:ok, _} ->
        {:ok, :started}
      {:error, {:cowboy, _}} ->
        raise "could not start the cowboy application. Please ensure it is listed " <>
              "as a dependency both in deps and application in your mix.exs"
    end
    routes = [
      {:_, Raxx.Adapters.Cowboy.Handler, app}
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
end
