defmodule Raxx.Ace.ChunkedTest do
  use ExUnit.Case, async: true

  setup do
    raxx_app = {__MODULE__, %{chunks: ["Hello,", " ", "World", "!"]}}
    {:ok, endpoint} = Ace.TCP.start_link({Raxx.Adapters.Ace.Handler, raxx_app}, port: 0)
    {:ok, port} = Ace.TCP.Endpoint.port(endpoint)
    {:ok, %{port: port}}
  end

  def handle_request(_r, %{chunks: chunks}) do
    Process.send_after(self(), :tick, 100)
    Raxx.Chunked.upgrade({__MODULE__, chunks})
    # TODO
    # - implicity leave state and model
    # - pass custom headers
    # - pass custom status?
  end

  def handle_info(:tick, [chunk | rest]) do
    Process.send_after(self(), :tick, 100)
    {:chunk, chunk, rest}
  end
  def handle_info(:tick, []) do
    {:close, []}
  end

  test "sends a chunked response with status and headers", %{port: port} do
    {:ok, response} = HTTPoison.get("localhost:#{port}")
    assert "Hello, World!" == response.body
  end
end
