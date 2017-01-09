defmodule Raxx.TestSupport.Forwarder do
  def handle_request(request, env) do
    pid = Map.get(env, :target)
    send(pid, request)
    Raxx.Response.no_content()
  end
end

defmodule Raxx.Adapters.RequestCase do
  use ExUnit.CaseTemplate

  using do
    quote location: :keep do
      test "request shows correct scheme", %{port: port} do
        {:ok, _resp} = HTTPoison.get("localhost:#{port}")
        assert_receive %{scheme: "http"}
      end

      test "request shows localhost", %{port: port} do
        {:ok, _resp} = HTTPoison.get("localhost:#{port}")
        assert_receive %{host: "localhost"}
      end

      test "request shows correct host", %{port: port} do
        {:ok, _resp} = HTTPoison.get("0.0.0.0:#{port}")
        assert_receive %{host: "0.0.0.0"}
      end

      test "request shows correct port", %{port: port} do
        {:ok, _resp} = HTTPoison.get("localhost:#{port}")
        assert_receive %{port: ^port}
      end

      test "request shows correct method", %{port: port} do
        {:ok, _resp} = HTTPoison.get("localhost:#{port}")
        assert_receive %{method: :GET}
      end

      test "request shows correct method when posting", %{port: port} do
        {:ok, _resp} = HTTPoison.post("localhost:#{port}", "")
        assert_receive %{method: :POST}
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

      test "request shows correct header", %{port: port} do
        {:ok, _resp} = HTTPoison.get("localhost:#{port}/", [{"content-type", "unknown/stuff"}])
        assert_receive %{headers: headers}
        assert {"content-type", "unknown/stuff"} == List.keyfind(headers, "content-type", 0)
      end

      test "request downcases headers", %{port: port} do
        {:ok, _resp} = HTTPoison.get("localhost:#{port}/", [{"Content-Type", "unknown/stuff"}])
        assert_receive %{headers: headers}
        assert {"content-type", "unknown/stuff"} == List.keyfind(headers, "content-type", 0)
      end

      test "request has correct body", %{port: port} do
        {:ok, _resp} = HTTPoison.post("localhost:#{port}", "blah blah")
        assert_receive %{body: body}
        assert "blah blah" == body
      end
    end
  end
end
defmodule Raxx.Adapters.ResponseCase do
  use ExUnit.CaseTemplate

  using do
    quote location: :keep do
      def handle_request(request = %{path: path = [function | _rest]}, _env) do
        apply(__MODULE__, String.to_atom(function), [request])
      end

      def hello_world(request) do
        body = "Hello, World!"
        Raxx.Response.ok(body, [
          {"content-length", "#{:erlang.iolist_size(body)}"},
          {"custom-header", "my-value"}
        ])
      end

      test "Hello response has correct status", %{port: port} do
        {:ok, response} = HTTPoison.get("localhost:#{port}/hello_world", [])
        assert %{status_code: 200} = response
      end

      test "Hello response has content length header", %{port: port} do
        {:ok, %{headers: headers}} = HTTPoison.get("localhost:#{port}/hello_world", [])
        assert {"content-length", "13"} = List.keyfind(headers, "content-length", 0)
      end

      test "Hello response has custom header", %{port: port} do
        {:ok, %{headers: headers}} = HTTPoison.get("localhost:#{port}/hello_world", [])
        assert {"custom-header", "my-value"} = List.keyfind(headers, "custom-header", 0)
      end

      test "Hello response greeting body", %{port: port} do
        {:ok, %{body: body}} = HTTPoison.get("localhost:#{port}/hello_world", [])
        assert "Hello, World!" = body
      end
    end
  end
end
defmodule Raxx.Adapters.ChunkedCase do
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
{:ok, _} = Application.ensure_all_started(:httpoison)
ExUnit.start()
