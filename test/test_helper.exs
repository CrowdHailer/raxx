defmodule Raxx.TestSupport.Forwarder do
  def handle_request(request, env) do
    pid = Map.get(env, :target)
    send(pid, request)
    Raxx.Response.no_content()
  end
end

defmodule Raxx.TestSupport.Responder do
  def handle_request(_request, env) do
    pid = Map.get(env, :target)
    send(pid, {:request, self()})
    receive do
      {:response, response} ->
        response
    end
  end
end

defmodule Raxx.TestSupport.Streaming do
  def handle_request(_request, env) do
    [initial | chunks] = env.chunks
    Process.send_after(self(), chunks, 500)
    Raxx.Streaming.upgrade(__MODULE__, env, %{initial: initial})
  end

  # handle cast?
  def handle_info([], _env) do
    :nosend
  end
  def handle_info([message | chunks], _env) do
    Process.send_after(self(), chunks, 500)
    {:send, message}
  end
end

case Application.ensure_all_started(:cowboy) do
  {:ok, _} ->
    :ok
  {:error, {:cowboy, _}} ->
    raise "could not start the cowboy application. Please ensure it is listed " <>
          "as a dependency both in deps and application in your mix.exs"
end

defmodule Raxx.Adapters.RequestCase do
  use ExUnit.CaseTemplate

  using do
    quote location: :keep do
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
        Raxx.Response.ok(body, [{"content-length", :erlang.iolist_size(body)}])
      end

      test "Hello response has correct status", %{port: port} do
        {:ok, response} = HTTPoison.get("localhost:#{port}/hello_world", [])
        assert %{status_code: 200} = response
      end

      test "Hello response has content length header", %{port: port} do
        {:ok, %{headers: headers}} = HTTPoison.get("localhost:#{port}/hello_world", [])
        IO.inspect(headers)
        assert {"content-length", "13"} = List.keyfind(headers, "content-length", 0)
      end

      test "Hello response greeting body", %{port: port} do
        {:ok, %{body: body}} = HTTPoison.get("localhost:#{port}/hello_world", [])
        assert "Hello, World!" = body
      end
    end
  end
end
ExUnit.start()
