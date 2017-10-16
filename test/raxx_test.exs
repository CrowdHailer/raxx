defmodule RaxxTest do
  use ExUnit.Case
  import Raxx
  doctest Raxx

  test "cannot set an uppercase header" do
    assert_raise RuntimeError, "Header keys must be lowercase", fn ->
      Raxx.response(:ok)
      |> Raxx.set_header("Foo", "Bar")
    end
  end

  test "cannot set a header twice" do
    assert_raise RuntimeError, "Headers should not be duplicated", fn ->
      Raxx.response(:ok)
      |> Raxx.set_header("x-foo", "one")
      |> Raxx.set_header("x-foo", "two")
    end
  end
end
