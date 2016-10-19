defmodule Raxx.Ace.StreamingTest do
  use ExUnit.Case, async: true

  setup do
    raxx_app = {__MODULE__, %{chunks: ["Hello,", " ", "World", "!"]}}
    {:ok, endpoint} = Ace.TCP.start_link({Raxx.Adapters.Ace.Handler, raxx_app}, port: 0)
    {:ok, port} = Ace.TCP.Endpoint.port(endpoint)
    {:ok, %{port: port}}
  end

  def handle_request(_r, state) do
    # Raxx.chunk({__MODULE__, state}, headers: [])
    Process.send_after(self(), :tick, 100)
    %Raxx.Chunked{app: {__MODULE__, state}}
  end

  def handle_info(:tick, state = %{chunks: [chunk | rest]}) do
    Process.send_after(self(), :tick, 100)
    {:chunk, chunk, %{state | chunks: rest}}
  end
  def handle_info(:tick, state = %{chunks: []}) do
    {:close, state}
  end

  test "sends a chunked response with status and headers", %{port: port} do
    {:ok, response} = HTTPoison.get("localhost:#{port}")
    assert "Hello, World!" == response.body
  end
end
