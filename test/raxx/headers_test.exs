# The headers are retrieved as a map with string keys and a list of strings
# Known headers are fetched with an atom key
# Can I Overwrite Access
# headers[:Cookie] -> Cookies
# headers["cookie"] -> string

# Response.set_cookie(response, "key", "value", opts)
# Response.set_cookie(response, cookie)
#
# defmodule Response do
#   def set_cookie(request = %{headers: => headers}, key, value, opt) do
#     new_headers = Headers.set_cookie(headers, key, value, opts)
#     %{request | headers: new_headers}
#   end
# end
#
# Headers.set_cookie(response, "key", "value", opts)
# Headers.set_cookie(response, cookie)



defmodule Raxx.HeadersTest do
  defmodule Headers do
    def set_cookie(headers, key, value) do
      cookies = Map.get(headers, "set-cookie", [])
      Map.merge(headers, %{"set-cookie" => cookies ++ ["#{key}=#{value}"]})
    end
  end
  use ExUnit.Case
  @set_cookie "set-cookie"

  test "can set a single cookie" do
    %{@set_cookie => cookie_headers} = Headers.set_cookie(%{}, "foo", "bar")
    assert ["foo=bar"] = cookie_headers
  end
  test "can add a single cookie" do
    %{@set_cookie => cookie_headers} = Headers.set_cookie(%{@set_cookie => ["foo=bar"]}, "baz", "fee")
    assert ["foo=bar", "baz=fee"] = cookie_headers
  end
end

defmodule Raxx.CookieTest do
  alias Raxx.Cookie
  use ExUnit.Case
  test "can set a cookie value" do
    assert "foo=bar" == Cookie.set_cookie_string("foo", "bar")
  end

  test "can set a cookie with a domain" do
    assert "foo=bar; Domain=example.com" == Cookie.set_cookie_string("foo", "bar", %{domain: "example.com"})
  end

  test "can set a secure cookie" do
    assert "foo=bar; Secure" == Cookie.set_cookie_string("foo", "bar", %{secure: true})
  end

  test "can set a http only cookie" do
    assert "foo=bar; HttpOnly" == Cookie.set_cookie_string("foo", "bar", %{http_only: true})
  end
end
