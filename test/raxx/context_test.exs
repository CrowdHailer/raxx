defmodule Raxx.ContextTest do
  use ExUnit.Case

  alias Raxx.Context

  @moduletag :context

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

  test "get_snapshot/0 gets all context values, but none of the other process dictionary values" do
    Process.put("this", "that")
    assert %{} == Context.get_snapshot()

    Context.set(:foo, 1)
    Context.set(:bar, 2)

    Process.put(:bar, 10)
    Process.put(:baz, 11)

    assert %{foo: 1, bar: 2} == Context.get_snapshot()
  end

  test "restore_snapshot/1 doesn't affect 'normal' process dictionary values" do
    empty_snapshot = Context.get_snapshot()
    Process.put("this", "that")

    assert :ok = Context.restore_snapshot(empty_snapshot)
    assert "that" == Process.get("this")
  end

  test "delete/1 deletes the given section from the context (but nothing else)" do
    Context.set(:foo, 1)
    Context.set(:bar, 2)

    assert 1 == Context.delete(:foo)
    assert nil == Context.retrieve(:foo)

    # this makes sure the value wasn't just set to nil and the other values are untouched
    assert %{bar: 2} == Context.get_snapshot()
  end

  test "restore_snapshot/1 restores the snapshot to the process dictionary" do
    Context.set(:foo, 1)
    Context.set(:bar, 2)

    snapshot = Context.get_snapshot()

    Context.delete(:foo)
    Context.delete(:bar)

    assert %{} == Context.get_snapshot()

    Context.restore_snapshot(snapshot)

    assert %{foo: 1, bar: 2} == Context.get_snapshot()
  end

  test "restore_snapshot/1 doesn't leave behind any section values from before the restore operation" do
    Context.set(:foo, 1)
    Context.set(:bar, 2)

    snapshot = Context.get_snapshot()

    Context.set(:bar, 22)
    Context.set(:baz, 3)

    assert :ok = Context.restore_snapshot(snapshot)

    assert %{foo: 1, bar: 2} == Context.get_snapshot()
  end
end
