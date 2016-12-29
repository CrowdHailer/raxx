defmodule Raxx.ResponseTest do
  alias Raxx.Response

  use ExUnit.Case

  # STATUS
  test "can create a informational response" do
    response = Response.continue()
    assert Response.informational?(response)
  end

  test "can create an successful response" do
    response = Response.ok()
    assert response.status == 200
    assert Response.success?(response)
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
end
