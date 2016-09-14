defmodule Raxx.TestSupport.Chunks do
  def handle_request(request, env) do
    IO.inspect(env)
    Raxx.Response.ok("ss")
  end
end

defmodule Raxx.Elli.ChunkTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, _pid} = :elli.start_link [
      callback: Raxx.Adapters.Elli.Handler,
      callback_args: {Raxx.TestSupport.Chunks, %{chunks: ["1", "2", "3"]}},
      port: 2020]
    {:ok, %{port: 2020}}
  end

  test "sends chunks", %{port: port} do
    headers = %{"accept" => "text/event-stream",
      "cache-control" => "no-cache",
      "connection" => "keep-alive"}
    IO.inspect(port)
    {:ok, %{id: ref}} = HTTPoison.get("localhost:#{port}", headers, stream_to: self)
    # receive do
    #   a ->
    #     IO.inspect(a)
    # end
    # receive do
    #   a ->
    #     IO.inspect(a)
    # end
    # receive do
    #   a ->
    #     IO.inspect(a)
    # end
    # receive do
    #   a ->
    #     IO.inspect(a)
    # end
    # assert_receive %{code: 200, id: ^ref}
    # assert_receive %{headers: headers, id: ^ref}, 1_000
    # IO.inspect(headers)
    # assert_receive %{chunk: _, id: ^ref}, 1_000
    # assert_receive %{chunk: _, id: ^ref}, 1_000
  end
end
