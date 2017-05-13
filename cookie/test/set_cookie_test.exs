defmodule SetCookieTest do
  use ExUnit.Case
  import SetCookie, only: [
    parse: 1,
    serialize: 2,
    serialize: 3,
    expire: 1,
    expire: 2
  ]
  doctest SetCookie
end
