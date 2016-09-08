defmodule Raxx.ResponseTest do
  alias Raxx.Response

  use ExUnit.Case

  test "can create a no_content response" do
    response = Response.no_content()
    assert response.body == ""
    assert response.status == 204
  end

  test "can create an ok response with string content" do
    content = "my content"
    response = Response.ok(content)
    assert response.body == content
    assert response.status == 200
  end

  test "can create a not_found response with extra headers" do
    response = Response.ok("nothing here", %{"my-header" => "my-value"})
    assert response.headers["my-header"] == "my-value"
  end

  test "can set a session cookie" do
    response = Response.ok() |> Response.set_cookie("foo", "bar")
    assert %{headers: %{"set-cookie" => ["foo=bar"]}} = response
  end

  test "can expire a cookie" do
    response = Response.ok() |> Response.expire_cookie("foo")
    %{headers: %{"set-cookie" => [set_cookie_string]}} = response
    assert "foo=;expires=Thu, 01 Jan 1970 00:00:00 GMT" == set_cookie_string
  end
end
