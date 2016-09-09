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

  test "can set a cookie value with an expiry date" do
    cookie = Cookie.new("foo", "bar", %{expires: {{2016, 9, 8}, {13, 12, 25}}})
    assert "foo=bar; Expires=Thu, 08 Sep 2016 13:12:25 GMT" == Cookie.set_cookie_string(cookie)
  end

  test "can set a cookie with a max age" do
    cookie = Cookie.new("foo", "bar", %{max_age: 24 * 60 * 60})
    assert "foo=bar; Max-Age=86400" == Cookie.set_cookie_string(cookie)
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
