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

  test "header values cannot contain control feed charachter" do
    assert_raise RuntimeError,
                 "Header values must not contain control feed (\\r) or newline (\\n)",
                 fn ->
                   Raxx.response(:ok)
                   |> Raxx.set_header("foo", "Bar\r")
                 end
  end

  test "header values cannot contain newline charachter" do
    assert_raise RuntimeError,
                 "Header values must not contain control feed (\\r) or newline (\\n)",
                 fn ->
                   Raxx.response(:ok)
                   |> Raxx.set_header("foo", "Bar\n")
                 end
  end

  test "cannot set a connection header" do
    assert_raise RuntimeError,
                 "Cannot set a connection specific header, see documentation for details",
                 fn ->
                   Raxx.response(:ok)
                   |> Raxx.set_header("connection", "keep-alive")
                 end
  end

  test "cannot set a header twice" do
    assert_raise RuntimeError, "Headers should not be duplicated", fn ->
      Raxx.response(:ok)
      |> Raxx.set_header("x-foo", "one")
      |> Raxx.set_header("x-foo", "two")
    end
  end

  test "cannot get an uppercase header" do
    assert_raise RuntimeError, "Header keys must be lowercase", fn ->
      Raxx.response(:ok)
      |> Raxx.get_header("Foo")
    end
  end

  test "Cannot set the body of an informational (1xx) response" do
    assert_raise ArgumentError, fn ->
      Raxx.response(:continue)
      |> Raxx.set_body("Hello, World!")
    end
  end

  test "Cannot set the body of an no content response" do
    assert_raise ArgumentError, fn ->
      Raxx.response(:no_content)
      |> Raxx.set_body("Hello, World!")
    end
  end

  test "Cannot set the body of an not modified response" do
    assert_raise ArgumentError, fn ->
      Raxx.response(:not_modified)
      |> Raxx.set_body("Hello, World!")
    end
  end
end
