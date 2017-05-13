defmodule CookieTest do
  use ExUnit.Case
  import Cookie, only: [parse: 1]
  doctest Cookie
end
