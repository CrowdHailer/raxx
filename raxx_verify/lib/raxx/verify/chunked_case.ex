defmodule Raxx.Verify.ChunkedCase do
  use ExUnit.CaseTemplate

  using do
    quote location: :keep do
      def handle_request(%{path: []}, %{chunks: chunks}) do
        Process.send_after(self(), :tick, 100)
        Raxx.Chunked.upgrade({__MODULE__, chunks}, headers: [{"content-type", "text/event-stream"}])
        # TODO implicity leave state and model
        # TODO pass custom status?
      end
      def handle_request(%{path: ["sse"]}, _) do
        Process.send_after(self(), {:sse, :tick}, 100)
        Raxx.ServerSentEvents.upgrade({__MODULE__, :noenv})
      end

      def handle_info(:tick, [chunk | rest]) do
        Process.send_after(self(), :tick, 100)
        {:chunk, chunk, rest}
      end
      def handle_info(:tick, []) do
        {:close, []}
      end
      def handle_info({:sse, :tick}, _) do
        event = Raxx.ServerSentEvents.Event.new("data", event: "nudge")
        {:chunk, Raxx.ServerSentEvents.Event.to_chunk(event), :noenv}
      end

      test "sends a chunked response with status and headers", %{port: port} do
        {:ok, response} = HTTPoison.get("localhost:#{port}")
        assert "Hello, World!" == response.body
        assert {"content-type", "text/event-stream"} == List.keyfind(response.headers, "content-type", 0)
      end
      test "sends server send events", %{port: port} do
        {:ok, ref} = HTTPoison.get("localhost:#{port}/sse", %{}, stream_to: self)
        assert_receive %{code: 200}
        assert_receive %{headers: _}
        assert_receive %{chunk: "event: nudge\r\ndata: data\r\n\r\n"}, 1000
      end
    end
  end
end
