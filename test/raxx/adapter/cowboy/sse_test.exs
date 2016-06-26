defmodule SSERouter do
  def call(request, opts) do
    %{
      upgrade: Raxx.ServerSentEvents,
      handler: __MODULE__,
      options: opts ++ ["3"]
    }
  end

  def open(options) do
    Process.send_after(self, {:count, options}, 100)
    {:nosend, :some_state}
  end

  def info({:count, [n | rest]}, state) do
    Process.send_after(self, {:count, rest}, 100)
    {:send, n, state}
  end
  def info({:count, []}, state) do
    {:close, state}
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
    HTTPoison.get("localhost:#{port}", headers, stream_to: self)
    receive do
      a -> IO.inspect(a)
    end
    receive do
      a -> IO.inspect(a)
    end
    receive do
      a -> IO.inspect(a)
    end
    receive do
      a -> IO.inspect(a)
    end
    receive do
      a -> IO.inspect(a)
    end
    receive do
      a -> IO.inspect(a)
    end
  end

  defp raxx_up(port, app \\ {Forwarder, self}) do
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
