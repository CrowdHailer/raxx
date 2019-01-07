defmodule Raxx.ContextTest do
  use ExUnit.Case

  alias Raxx.Context

  describe "section functions" do
    test "get_section returns default values if the value is not present" do
      assert :default == Context.get_section(:foo, :default)
      assert nil == Context.get_section(:foo, nil)
    end

    test "get_section returns an empty map as the default default value" do
      assert %{} == Context.get_section(:foo)
    end

    test "get_section returns the most recently set section value" do
      IO.inspect Context.put_section(:foo, 1)

    end
  end
end
