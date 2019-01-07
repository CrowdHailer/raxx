defmodule Raxx.ContextTest do
  use ExUnit.Case

  alias Raxx.Context

  describe "section functions" do
    test "retrieve returns default values if the value is not present" do
      assert :default == Context.retrieve(:foo, :default)
      assert nil == Context.retrieve(:foo, nil)
    end

    test "retrieve returns nil as the default default value" do
      assert nil == Context.retrieve(:foo)
    end

    test "retrieve returns the most recently set section value" do
      Context.set(:foo, 1)
      assert 1 == Context.retrieve(:foo)
      Context.set(:foo, 2)
      assert 2 == Context.retrieve(:foo)
    end

    test "set returns the previous section value" do
      assert nil == Context.set(:foo, 1)
      assert 1 == Context.set(:foo, 2)
    end
  end
end
