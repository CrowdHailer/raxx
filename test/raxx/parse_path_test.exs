defmodule Raxx.ParsePathTest do
  use ExUnit.Case
  import Raxx
  import Raxx.ParsePath

  doctest Raxx.ParsePath

  test "parse a path" do
    request = request(:GET, "/foo/bar/baz/")
    assert ["foo", "bar", "baz"] == split_path(request).path
  end

  test "doesn't process request where path isn't a string" do
    request = request(:GET, "/foo/bar/")
    request = %{request | path: ["", "foo", "bar", ""]}
    assert ["", "foo", "bar", ""] == split_path(request).path
  end
end
