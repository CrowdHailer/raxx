defmodule Raxx.Streaming do
  def setup(mod, env, opts \\ %{}) do
    {__MODULE__, mod, env, opts}
  end
end

defmodule Raxx.TestSupport.Chunks do
  def handle_request(request, env) do
    chunks = env.chunks
    IO.inspect(chunks)
    Process.send_after(self(), chunks, 500)
    Process.send_after(self(), {:chunk, "1232"}, 200)
    Raxx.Streaming.setup(__MODULE__, env, %{initial: "opening"})
  end

  # handle cast?
  def handle_info(message, env) do
    IO.inspect(message)
  end
end

defmodule Raxx.Elli.ChunkTest do
  use ExUnit.Case

  setup do
    port = 2111
    {:ok, _pid} = :elli.start_link [
      callback: Raxx.Adapters.Elli.Handler,
      callback_args: {Raxx.TestSupport.Chunks, %{chunks: ["1", "2", "3"]}},
      port: port]
    {:ok, %{port: port}}
  end

  @tag :skip
  # FIXME skipped test because I can't send arbitrary messages to elli request process
  test "sends chunks", %{port: port} do
    headers = %{"accept" => "text/event-stream",
      "cache-control" => "no-cache",
      "connection" => "keep-alive"}
    {:ok, %{id: ref}} = HTTPoison.get("localhost:#{port}", headers, stream_to: self)
    receive do
      a ->
        IO.inspect(a)
    end
    receive do
      a ->
        IO.inspect(a)
    end
    receive do
      a ->
        IO.inspect(a)
    end
    receive do
      a ->
        IO.inspect(a)
    end
    # assert_receive %{code: 200, id: ^ref}
    # assert_receive %{headers: headers, id: ^ref}, 1_000
    # IO.inspect(headers)
    # assert_receive %{chunk: _, id: ^ref}, 1_000
    # assert_receive %{chunk: _, id: ^ref}, 1_000
  end
end
