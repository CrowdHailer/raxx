# The headers are retrieved as a map with string keys and a list of strings
# Known headers are fetched with an atom key
# Can I Overwrite Access
# headers[:Cookie] -> Cookies
# headers["cookie"] -> string

# Response.set_cookie(response, "key", "value", opts)
# Response.set_cookie(response, cookie)

defmodule Raxx.CookieTest do
  alias Raxx.Cookie
  use ExUnit.Case
  test "can set a cookie value" do
    cookie = Cookie.new("foo", "bar")
    assert "foo=bar" == Cookie.set_cookie_string(cookie)
  end

  test "can set a cookie with a domain" do
    cookie = Cookie.new("foo", "bar", %{domain: "example.com"})
    assert "foo=bar; Domain=example.com" == Cookie.set_cookie_string(cookie)
  end

  test "can set a cookie with a path" do
    cookie = Cookie.new("foo", "bar", %{path: "/path"})
    assert "foo=bar; Path=/path" == Cookie.set_cookie_string(cookie)
  end

  test "can set a secure cookie" do
    cookie = Cookie.new("foo", "bar", %{secure: true})
    assert "foo=bar; Secure" == Cookie.set_cookie_string(cookie)
  end

  test "can set a http only cookie" do
    cookie = Cookie.new("foo", "bar", %{http_only: true})
    assert "foo=bar; HttpOnly" == Cookie.set_cookie_string(cookie)
  end
end
