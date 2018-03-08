defmodule Raxx.LoggerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  defmodule DefaultServer do
    use Raxx.Server
    use Raxx.Logger
  end

  test "Request and response information is logged" do
    request = Raxx.request(:GET, "http://example.com:1234/foo?bar=value")

    log =
      capture_log(fn ->
        DefaultServer.handle_head(request, :state)
      end)

    assert String.contains?(log, "GET /foo?bar=value")
    assert String.contains?(log, "Sent 404 in")
  end

  test "Request context is added to logger metadata" do
    request = Raxx.request(:GET, "http://example.com:1234/foo?bar=value")

    _log =
      capture_log(fn ->
        DefaultServer.handle_head(request, :state)
      end)

    metadata = Logger.metadata()
    assert Raxx.LoggerTest.DefaultServer = Keyword.get(metadata, :"raxx.app")
    assert :http = Keyword.get(metadata, :"raxx.scheme")
    assert "example.com:1234" = Keyword.get(metadata, :"raxx.authority")
    assert :GET = Keyword.get(metadata, :"raxx.method")
    assert "[\"foo\"]" = Keyword.get(metadata, :"raxx.path")
    assert "%{\"bar\" => \"value\"}" = Keyword.get(metadata, :"raxx.query")
  end
end
