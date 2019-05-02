defmodule Raxx.View.LayoutTest do
  use ExUnit.Case

  defmodule Helpers do
    def helper_function() do
      "helper_function"
    end
  end

  defmodule DefaultLayout do
    use Raxx.View.Layout,
      imports: [__MODULE__, Helpers],
      optional: [foo: "foo", bar: "foo"]

    def layout_function() do
      "layout_function"
    end
  end

  defmodule DefaultLayoutExample do
    use DefaultLayout,
      arguments: [:x, :y],
      optional: [bar: "bar"],
      template: "layout_test_example.html.eex"
  end

  test "List of imports are available in template" do
    assert ["foobar", "7", "layout_function", "helper_function" | _] =
             lines("#{DefaultLayoutExample.html(3, 4)}")
  end

  test "optional arguments can be overwritten in layout" do
    assert ["bazbaz" | _] = lines("#{DefaultLayoutExample.html(3, 4, foo: "baz", bar: "baz")}")
  end

  test "File and line information is correct" do
    assert [_, _, _, _, view_file, layout_file] = lines("#{DefaultLayoutExample.html(3, 4)}")
    assert Path.join(__DIR__, "/layout_test_example.html.eex") <> ":4" == view_file
    assert Path.join(__DIR__, "/layout_test.html.eex") <> ":3" == layout_file
  end

  defp lines(text) do
    String.split(text, ~r/\R/)
    |> Enum.reject(fn line -> line == "" end)
  end
end
