defmodule Forwarder do
  import Raxx.Response
  def handle_request(request, pid) do
    send(pid, request)
    ok("done")
  end
end
defmodule FakeHeader do
  import Raxx.Response
  def handle_request(_request, _env) do
    ok("done", %{"custom-header" => "my-value"})
  end
end

defmodule StringReply do
  def handle_request(_request, %{body: body}) do
    body
  end
end

defmodule RedirectRequest do
  import Raxx.Response
  def handle_request(%{path: ["ping"]}, %{}) do
    redirect("/pong")
  end

  def handle_request(_request, _env) do
    ok("pong")
  end
end

defmodule Raxx.CowboyTest do
  use ExUnit.Case, async: true

  def raxx_up(%{case: case, test: test}, app \\ {Forwarder, self}) do
    name = {case, test}
    routes = [
      {:_, Raxx.Adapters.Cowboy.Handler, app}
    ]
    dispatch = :cowboy_router.compile([{:_, routes}])
    env = [dispatch: dispatch]
    {:ok, _pid} = :cowboy.start_http(
      name,
      2,
      [port: 0],
      [env: env]
    )
    :ranch.get_port(name)
  end

  test "add custom headers to request", context do
    port = raxx_up(context, {FakeHeader, %{}})
    {:ok, %{headers: headers}} = HTTPoison.get("localhost:#{port}")
    header = Enum.find(headers, fn
      ({"custom-header", _}) -> true
      _ -> false
    end)
    assert {_, "my-value"} = header
  end

  test "redirection", context do
    port = raxx_up(context, {RedirectRequest, %{}})
    {:ok, %{body: body}} = HTTPoison.get("localhost:#{port}/ping", %{}, [follow_redirect: true])
    assert "pong" == body
  end

  test "post some unknown binary content", context do
    port = raxx_up(context)
    {:ok, _resp} = HTTPoison.post("localhost:#{port}", "blah blah", [{"content-type", "unknown/stuff"}])
    assert_receive %{headers: %{"content-type" => type}, body: body}
    assert "unknown/stuff" == type
    assert "blah blah" == body
  end

  test "post simple form encoding", context do
    port = raxx_up(context)
    {:ok, _resp} = HTTPoison.post("localhost:#{port}", {:form, [{"foo", "bar"}]})
    assert_receive %{headers: %{"content-type" => type}, body: body}
    assert "application/x-www-form-urlencoded" <> _ = type
    assert %{"foo" => "bar"} == body
  end

  test "post multipart form with file", context do
    port = raxx_up(context)
    body = {:multipart, [{"foo", "bar"}, {:file, "/etc/hosts"}]}
    {:ok, _resp} = HTTPoison.post("localhost:#{port}", body)
    assert_receive %{headers: %{"content-type" => type}, body: body}
    assert "multipart/form-data;" <> _ = type
    assert %{"foo" => "bar", "file" => file} = body
    assert file.contents
  end

  test "assumed content type is html", context do
    port = raxx_up(context)
    {:ok, resp} = HTTPoison.get("localhost:#{port}")
    {"content-type", content_type} = Enum.find(resp.headers, fn
      ({"content-type", _}) -> true
      _ -> false
    end)
    assert "text/html" == content_type
  end
end
