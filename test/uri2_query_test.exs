defmodule URI2.QueryTest do
  use ExUnit.Case
  doctest URI2.Query
  import URI2.Query

  test "decoding empty fields" do
    {:ok, query} = decode("=")
    assert query[""] == ""
    {:ok, query} = decode("key=")
    assert query["key"] == ""
    {:ok, query} = decode("=value")
    assert query[""] == "value"
  end

  test "confused queries" do
    {:error, reason} = decode("x=1&x=1")
    assert {:key_already_defined_as, "1"} == reason

    {:error, reason} = decode("x=1&x[]=1")
    assert {:key_already_defined_as, "1"} == reason

    {:error, reason} = decode("x=1&x[y]=1")
    assert {:key_already_defined_as, "1"} == reason
  end
end
