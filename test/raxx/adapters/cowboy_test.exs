defmodule Raxx.CowboyTest do
  use ExUnit.Case, async: true

    @tag :skip
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

  @tag :skip
  test "post simple form encoding", context do
    port = raxx_up(context)
    {:ok, _resp} = HTTPoison.post("localhost:#{port}", {:form, [{"foo", "bar"}]})
    assert_receive %{headers: %{"content-type" => type}, body: body}
    assert "application/x-www-form-urlencoded" <> _ = type
    assert %{"foo" => "bar"} == body
  end

  @tag :skip
  test "post multipart form with file", context do
    port = raxx_up(context)
    body = {:multipart, [{"foo", "bar"}, {:file, "/etc/hosts"}]}
    {:ok, _resp} = HTTPoison.post("localhost:#{port}", body)
    assert_receive %{headers: %{"content-type" => type}, body: body}
    assert "multipart/form-data;" <> _ = type
    assert %{"foo" => "bar", "file" => file} = body
    assert file.contents
  end

  @tag :skip
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
