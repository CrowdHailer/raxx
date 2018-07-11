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

  test "header values cannot contain control feed character" do
    assert_raise RuntimeError,
                 "Header values must not contain control feed (\\r) or newline (\\n)",
                 fn ->
                   Raxx.response(:ok)
                   |> Raxx.set_header("foo", "Bar\r")
                 end
  end

  test "header values cannot contain newline character" do
    assert_raise RuntimeError,
                 "Header values must not contain control feed (\\r) or newline (\\n)",
                 fn ->
                   Raxx.response(:ok)
                   |> Raxx.set_header("foo", "Bar\n")
                 end
  end

  test "duplicate headers are allowed" do
    response =
      Raxx.response(:ok)
      |> Raxx.set_header("x-foo", "one")
      |> Raxx.set_header("x-foo", "two")

    assert Enum.sort(response.headers) == [{"x-foo", "one"}, {"x-foo", "two"}],
           "Duplicate headers are allowed"
  end

  test "cannot get an uppercase header" do
    assert_raise RuntimeError, "Header keys must be lowercase", fn ->
      Raxx.response(:ok)
      |> Raxx.get_header("Foo")
    end
  end
end
