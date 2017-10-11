defmodule Raxx.ServerTest do
  use ExUnit.Case
  doctest Raxx.Server
  import ExUnit.CaptureLog

  defmodule DefaultServer do
    use Raxx.Server
  end

  test "default response is returned for the root page" do
    request = Raxx.request(:GET, "/")
    response = DefaultServer.handle_request(request, :state)

    assert String.contains?(response.body, "DefaultServer")
    assert String.contains?(response.body, "@impl Raxx.Server")
    assert 200 = response.status
  end

  test "default response is returned for a streamed request" do
    request = Raxx.request(:POST, "/")
    |> Raxx.set_body(true)
    {[], state} = DefaultServer.handle_headers(request, :state)
    {[], state} = DefaultServer.handle_fragment("Hello, World!", state)
    response = DefaultServer.handle_trailers([], state)

    assert String.contains?(response.body, "DefaultServer")
    assert String.contains?(response.body, "@impl Raxx.Server")
    assert 200 = response.status
  end

  test "handle_info logs error" do
    logs = capture_log fn() ->
      DefaultServer.handle_info(:foo, :state)
    end
    assert String.contains?(logs, "unexpected message")
    assert String.contains?(logs, ":foo")
  end
end
