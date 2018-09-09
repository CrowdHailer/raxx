defmodule EEx.HTMlTest do
  use ExUnit.Case, async: true
  import EEx.HTML
  doctest EEx.HTML

  test "raw accepts binary" do
    assert "Hello, World!" == "#{raw("Hello, World!")}"
  end

  test "raw accepts iolist" do
    assert "Hello, World!" == "#{raw(["Hello, ", ["World!"]])}"
  end

  test "raw accepts any term that implements String.Chars" do
    assert "Hello, World!" == "#{raw(:"Hello, World!")}"
    assert "125" == "#{raw(125)}"
  end

  test "raises ArgumentError when not an iolist" do
    assert_raise(ArgumentError, fn ->
      raw([:foo])
    end)
  end
end
