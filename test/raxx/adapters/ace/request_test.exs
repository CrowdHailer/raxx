defmodule Raxx.Adapters.Ace.RequestTest do
  use Raxx.Adapters.RequestCase

  setup do
    raxx_app = {Raxx.TestSupport.Forwarder, %{target: self()}}
    {:ok, endpoint} = Ace.TCP.start_link({Raxx.Adapters.Ace.Handler, raxx_app}, port: 0)
    {:ok, port} = Ace.TCP.Endpoint.port(endpoint)
    {:ok, %{port: port}}
  end

  # TODO move to general request case
  test "post simple form encoding", %{port: port} do
    {:ok, _resp} = HTTPoison.post("localhost:#{port}", {:form, [{"string", "foo"}, {"number", 3}]})
    assert_receive request = %Raxx.Request{}
    assert {"application/x-www-form-urlencoded", _} = Raxx.Request.content_type(request)

    {:ok, form} = Raxx.Request.content(request)
    assert %{"number" => "3", "string" => "foo"} == form
  end

  # TODO move to general request case
  test "post multipart form with file", %{port: port} do
    body = {:multipart, [{"plain", "string"}, {:file, "test/hello.txt"}]}
    {:ok, _resp} = HTTPoison.post("localhost:#{port}", body)
    assert_receive request = %Raxx.Request{}
    assert {"multipart/form-data", _} = Raxx.Request.content_type(request)
    {:ok, %{"plain" => "string", "file" => upload}} = Raxx.Request.content(request)
    assert upload.filename == "hello.txt"
    assert upload.type == "text/plain"
  end

  test "test handles request with split start-line ", %{port: port} do
    request = """
    GET / HTTP/1.1
    Host: www.raxx.com

    """
    {:ok, socket} = :gen_tcp.connect({127,0,0,1}, port, [:binary])
    {first, second} = Enum.split(request |> String.split(""), 8)
    :gen_tcp.send(socket, Enum.join(first))
    :timer.sleep(10)
    :gen_tcp.send(socket, Enum.join(second))
    assert_receive %{host: "www.raxx.com", path: []}
  end

  test "test handles request with split headers ", %{port: port} do
    request = """
    GET / HTTP/1.1
    Host: www.raxx.com

    """
    {:ok, socket} = :gen_tcp.connect({127,0,0,1}, port, [:binary])
    {first, second} = Enum.split(request |> String.split(""), 25)
    :gen_tcp.send(socket, Enum.join(first))
    :timer.sleep(10)
    :gen_tcp.send(socket, Enum.join(second))
    assert_receive %{host: "www.raxx.com", path: []}
  end

  test "test handles request with split body ", %{port: port} do
    content = "Hello, World!\r\n"
    {first, second} = Enum.split(content |> String.split(""), 7)
    head = """
    GET / HTTP/1.1
    Host: www.raxx.com
    Content-Length: #{:erlang.iolist_size(content)}

    """
    {:ok, socket} = :gen_tcp.connect({127,0,0,1}, port, [:binary])
    :gen_tcp.send(socket, head <> Enum.join(first))
    :timer.sleep(10)
    :gen_tcp.send(socket, Enum.join(second))
    assert_receive %{host: "www.raxx.com", path: [], body: ^content}
  end

  test "truncates body to required length ", %{port: port} do
    content = "Hello, World!\r\n"
    head = """
    GET / HTTP/1.1
    Host: www.raxx.com
    Content-Length: #{:erlang.iolist_size(content)}

    """
    {:ok, socket} = :gen_tcp.connect({127,0,0,1}, port, [:binary])
    :gen_tcp.send(socket, head <> content <> "crap")
    :timer.sleep(10)
    assert_receive %{host: "www.raxx.com", path: [], body: ^content}
  end

  # need to test keep alive with crap forming start of next request
end
