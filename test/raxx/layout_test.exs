defmodule Raxx.LayoutTest do
  use ExUnit.Case

  defmodule Helpers do
    def helper_function() do
      "helper_function"
    end
  end

  defmodule DefaultLayout do
    use Raxx.Layout, imports: [__MODULE__, Helpers]

    def layout_function() do
      "layout_function"
    end
  end

  defmodule DefaultLayoutExample do
    use DefaultLayout,
      arguments: [:x, :y],
      template: "layout_test_example.html.eex"
  end

  test "List of imports are available in template" do
    assert ["7", "layout_function", "helper_function"] = lines(DefaultLayoutExample.html(3, 4))
  end

  defp lines(text) do
    String.split(text, ~r/\R/)
    |> Enum.reject(fn line -> line == "" end)
  end
end
