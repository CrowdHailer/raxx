defmodule Ace.HTTP.RequestTest do
  use Raxx.Verify.RequestCase

  setup do
    raxx_app = {Raxx.Verify.Forwarder, %{target: self()}}
    {:ok, endpoint} = Ace.HTTP.start_link(raxx_app, port: 0)
    {:ok, port} = Ace.HTTP.port(endpoint)
    {:ok, %{port: port}}
  end

  test "will handle special case '//'", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}//")
    assert_receive %{path: []}
  end

  # TODO move to general request case
  test "request shows correct nested query", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/?foo[]=a+b&foo[]=a%21")
    assert_receive %{query: %{"foo" => ["a b", "a!"]}}
  end

  # TODO move to general request case
  test "post simple form encoding", %{port: port} do
    {:ok, _resp} = HTTPoison.post("localhost:#{port}", {:form, [{"string", "foo"}, {"number", 3}]})
    assert_receive request = %Raxx.Request{}
    assert {"application/x-www-form-urlencoded", _} = Raxx.Headers.content_type(request)

    {:ok, form} = URI2.Query.decode(request.body)
    assert %{"number" => "3", "string" => "foo"} == form
  end

  # TODO move to general request case
  test "post multipart form with file", %{port: port} do
    body = {:multipart, [{"plain", "string"}, {:file, "test/hello.txt"}]}
    {:ok, _resp} = HTTPoison.post("localhost:#{port}", body)
    assert_receive request = %Raxx.Request{}
    assert {"multipart/form-data", _} = Raxx.Headers.content_type(request)
    {:ok, parsed} = Raxx.Parsers.Multipart.parse(request)
    %{"plain" => "string", "file" => upload} = Enum.into(parsed, %{})
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

  test "will handle two requests over the same connection", %{port: port} do
    request = """
    GET / HTTP/1.1
    Host: www.raxx.com

    """
    {:ok, socket} = :gen_tcp.connect({127,0,0,1}, port, [:binary])
    {first, second} = Enum.split(request |> String.split(""), 25)
    :gen_tcp.send(socket, request <> Enum.join(first))
    :timer.sleep(10)
    :gen_tcp.send(socket, Enum.join(second))
    :timer.sleep(10)
    assert_receive %{host: "www.raxx.com", path: [], body: nil}
    assert_receive %{host: "www.raxx.com", path: [], body: nil}
  end
end
