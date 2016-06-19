defmodule Forwarder do
  import Raxx.Response
  def call(request, pid) do
    send(pid, request)
    ok("done", %{"custom-header" => "my-value"})
  end
end
defmodule Raxx.CowboyTest do
  use ExUnit.Case, async: true

  setup_all do
    {:ok, agent} = Agent.start_link(fn -> 1 end)
    case Application.ensure_all_started(:cowboy) do
      {:ok, _} ->
        {:ok, %{agent: agent}}
      {:error, {:cowboy, _}} ->
        raise "could not start the cowboy application. Please ensure it is listed " <>
              "as a dependency both in deps and application in your mix.exs"
    end
  end

  setup %{agent: agent} do
    id = Agent.get_and_update(agent, fn (i) -> {i, i + 1}end)
    {:ok, %{port: 10_000 + id}}
  end

  def raxx_up(port) do
    routes = [
      {:_, Raxx.Adapters.Cowboy.Handler, {Forwarder, self}}
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

  test "add custom headers to request", %{port: port} do
    {:ok, _pid} = raxx_up(port)
    {:ok, %{headers: headers}} = HTTPoison.get("localhost:#{port}")
    header = Enum.find(headers, fn
      ({"custom-header", _}) -> true
      _ -> false
    end)
    assert {_, "my-value"} = header
  end

  test "post simple form encoding", %{port: port} do
    {:ok, _pid} = raxx_up(port)
    {:ok, _resp} = HTTPoison.post("localhost:#{port}", {:form, [{"foo", "bar"}]})
    assert_receive %{headers: %{"content-type" => type}, body: body}
    assert "application/x-www-form-urlencoded" <> _ = type
    assert %{"foo" => "bar"} == body
  end

  test "post multipart form with file", %{port: port} do
    {:ok, _pid} = raxx_up(port)
    body = {:multipart, [{"foo", "bar"}, {:file, "/etc/hosts"}]}
    {:ok, _resp} = HTTPoison.post("localhost:#{port}", body)
    assert_receive %{headers: %{"content-type" => type}, body: body}
    assert "multipart/form-data;" <> _ = type
    assert %{"foo" => "bar", "file" => file} = body
    assert file.contents
  end

  test "assumed content type is html", %{port: port} do
    {:ok, _pid} = raxx_up(port)
    {:ok, resp} = HTTPoison.get("localhost:#{port}")
    {"content-type", content_type} = Enum.find(resp.headers, fn
      ({"content-type", _}) -> true
      _ -> false
    end)
    assert "text/html" == content_type
  end

  test "setup cowboy", %{port: port} do
    {:ok, _pid} = raxx_up(port)
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{host: "localhost"}
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{port: ^port}
    # METHODS
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{method: "GET"}
    {:ok, _resp} = HTTPoison.post("localhost:#{port}", "")
    assert_receive %{method: "POST"}
    # PATH
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{path: []}
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/")
    assert_receive %{path: []}
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/sub/path")
    assert_receive %{path: ["sub", "path"]}
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/?")
    assert_receive %{path: []}
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/?#")
    assert_receive %{path: []}
    # QUERY
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{query: %{}}
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/?")
    assert_receive %{query: %{}}
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/?foo=bar")
    assert_receive %{query: %{"foo" => "bar"}}
    # TODO nested queries
    # {:ok, _resp} = HTTPoison.get("localhost:10001/?foo[]=1&foo[]=2")
    # assert_receive %{query: %{"foo" => ["1", "2"]}}
    # TODO invalid queries
    # {:ok, _resp} = HTTPoison.get("localhost:10001/?some-search")
    # assert_receive %{query: "?some-search"
  end
end
