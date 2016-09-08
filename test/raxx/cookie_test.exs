# The headers are retrieved as a map with string keys and a list of strings
# Known headers are fetched with an atom key
# Can I Overwrite Access
# headers[:Cookie] -> Cookies
# headers["cookie"] -> string

# Response.set_cookie(response, "key", "value", opts)
# Response.set_cookie(response, cookie)

defmodule Raxx.CookieTest do
  @moduledoc ~S"""
  For a good introduction too cookies check [http cookies explained](https://www.nczonline.net/blog/2009/05/05/http-cookies-explained/)

  There are a lot of issues when it comes to formatting cookies.
  The Wiki article for cookies discusses 3 relevant [RFC's](https://en.wikipedia.org/wiki/HTTP_cookie#History).
  - RFC 2109 (Feb 1997) as the first specification for third-party cookies.
  - RFC 2965 (Oct 2000) as a replacement to RFC 2109.
  - RFC 6265 (Apr 2011) A definitive specification of real world usage.

  The majority of this modules behaviour is directed by RCF 6265.
  Where possible this extends to variable and method naming.

  Additional sources are:
  - [the plug source code](https://github.com/elixir-lang/plug/blob/0b387966d2f21cf050ca666f328864b546b4e754/lib/plug/conn/cookies.ex)
  - [the rack source code](https://github.com/rack/rack/blob/95172a60fe5c2a3850163fc75e0981fe440c064e/lib/rack/utils.rb)

  Expires vs Max-Age
  This two cookie attributes both exist for the same functionality.
  i.e. giving a livetime to persisted cookies(if neither id given then the cookie is a session cookie).

  There is more detail at [HTTP Cookies: What's the difference between Max-age and Expires?](http://mrcoles.com/blog/cookies-max-age-vs-expires/)
  In summary max-age is the newer way to set cookie deletion.

  Raxx does not convert from expires to max age or visa-versa.
  If you need both set then both will need to be set by the application.
  """

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
