defmodule Raxx.ResponseTest do
  alias Raxx.Response

  use ExUnit.Case

  # STATUS
  test "can create an informational response" do
    response = Response.ok()
    assert response.status == 200
    assert Response.success?(response)
  end

  test "can create a successful response" do
    response = Response.continue()
    assert Response.informational?(response)
  end

  test "can create a redirect response" do
    response = Response.found()
    assert Response.redirect?(response)
  end

  test "can create a client error response" do
    response = Response.bad_request()
    assert Response.client_error?(response)
  end

  test "can create a server error response" do
    response = Response.not_implemented()
    assert Response.server_error?(response)
  end

  # CONTENT
  test "can create a no_content response with no content" do
    response = Response.no_content()
    assert response.body == ""
  end

  test "can create a response with string content" do
    content = "my content"
    response = Response.ok(content)
    assert response.body == content
  end

  # HEADERS
  test "can create a not_found response with extra headers" do
    response = Response.ok("nothing here", %{"my-header" => "my-value"})
    assert "my-value" == Response.get_header(response, "my-header")
  end

  test "can fetch content type header" do
    response = Response.ok("nothing here", %{"content-type" => ["text/plain"]})
    assert "text/plain" == Response.get_header(response, "Content-Type")
  end

  @tag :skip
  test "can calculate content-length from content" do
    # assert true
    # NOTE cowboy automatically sorts out the content length.
    # Setting the wrong length causes and error so this is not implemented.
    # Might need to be added in the future for other servers.
  end

  test "can set a session cookie" do
    response = Response.ok() |> Response.set_cookie("foo", "bar")
    assert %{headers: %{"set-cookie" => ["foo=bar"]}} = response
  end

  test "can set a secure cookie" do
    response = Response.ok() |> Response.set_cookie("foo", "bar", %{secure: true})
    assert %{headers: %{"set-cookie" => ["foo=bar; Secure"]}} = response
  end

  test "can expire a cookie" do
    response = Response.ok() |> Response.expire_cookie("foo")
    %{headers: %{"set-cookie" => [set_cookie_string]}} = response
    assert "foo=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/" == set_cookie_string
  end
end
