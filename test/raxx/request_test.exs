defmodule Raxx.RequestTest do
  use ExUnit.Case
  alias Raxx.Request

  describe "uri/1" do
    test "handles a basic https case correctly" do
      request = Raxx.request(:GET, "https://example.com/")
      uri = Request.uri(request)

      assert %URI{
               authority: "example.com",
               fragment: nil,
               host: "example.com",
               path: "/",
               port: 443,
               query: nil,
               scheme: "https",
               userinfo: nil
             } == uri
    end

    test "handles a basic http case correctly" do
      request = Raxx.request(:GET, "http://example.com/")
      uri = Request.uri(request)

      assert %URI{
               authority: "example.com",
               fragment: nil,
               host: "example.com",
               path: "/",
               port: 80,
               query: nil,
               scheme: "http",
               userinfo: nil
             } == uri
    end

    test "handles the case with normal path" do
      request = Raxx.request(:GET, "https://example.com/foo/bar")
      uri = Request.uri(request)
      assert uri.path == "/foo/bar"
    end

    test "handles the case with duplicate slashes" do
      request = Raxx.request(:GET, "https://example.com/foo//bar")
      uri = Request.uri(request)
      assert uri.path == "/foo//bar"
    end

    test "passes through the query" do
      request = Raxx.request(:GET, "https://example.com?foo=bar&baz=ban")
      uri = Request.uri(request)
      assert uri.query == "foo=bar&baz=ban"
    end

    test "if there's a port number in the request, it is contained in the authority, but not the host" do
      url = "https://example.com:4321/foo/bar"
      request = Raxx.request(:GET, url)
      uri = Request.uri(request)
      assert uri.host == "example.com"
      assert uri.authority == "example.com:4321"
      assert uri.port == 4321
    end

    # TODO test for the userinfo
  end
end
