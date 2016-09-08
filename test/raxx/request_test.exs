defmodule Raxx.RequestTest do
  alias Raxx.Request

  use ExUnit.Case

  test "can parse a singe cookie" do
    request = %Request{headers: %{"cookie" => ["foo=bar"]}}
    cookies = Request.parse_cookies(request)
    assert %{"foo" => "bar"} == cookies
  end

  test "can parse several cookies" do
    request = %Request{headers: %{"cookie" => ["foo=bar; baz=blob"]}}
    cookies = Request.parse_cookies(request)
    assert %{"foo" => "bar", "baz" => "blob"} == cookies
  end

  test "can parse an empty cookie header" do
    request = %Request{headers: %{"cookie" => [""]}}
    cookies = Request.parse_cookies(request)
    assert %{} == cookies
  end

  test "can parse request with no cookie" do
    request = %Request{headers: %{}}
    cookies = Request.parse_cookies(request)
    assert %{} == cookies
  end
end
