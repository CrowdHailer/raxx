defmodule Raxx.ViewTest do
  use ExUnit.Case

  defmodule DefaultTemplate do
    use Raxx.View, arguments: [:x, :y]
    defp private(), do: "DefaultTemplate"
  end

  defmodule WithLayout do
    use Raxx.View, arguments: [:x, :y], layout: "view_test_layout.html.eex"
    defp private(), do: "WithLayout"
  end

  defmodule AbsoluteTemplate do
    use Raxx.View, arguments: [:x, :y], template: Path.join(__DIR__, "view_test_other.html.eex")
  end

  defmodule RelativeTemplate do
    use Raxx.View, arguments: [:x, :y], template: "view_test_other.html.eex"
  end

  test "Arguments and private module functions are available in templated" do
    assert ["8", "DefaultTemplate"] = lines(DefaultTemplate.html(3, 5))
  end

  test "Render will set content-type and body" do
    response =
      Raxx.response(:ok)
      |> DefaultTemplate.render(1, 2)

    assert ["3", "DefaultTemplate"] = lines(response.body)
    assert [{"content-type", "text/html"}] = response.headers
  end

  test "View can be rendered within a layout" do
    assert ["LAYOUT", "8", "WithLayout"] = lines(WithLayout.html(3, 5))
  end

  test "Default template can changed" do
    assert ["3", "5"] = lines(AbsoluteTemplate.html(3, 5))
  end

  test "Template path can be relative to calling file" do
    assert ["3", "5"] = lines(RelativeTemplate.html(3, 5))
  end

  test "An layout missing space for content is invalid" do
    assert_raise ArgumentError, fn ->
      defmodule Tmp do
        use Raxx.View, layout: "view_test_invalid_layout.html.eex"
      end
    end
  end

  test "Unexpected options are an argument error" do
    assert_raise ArgumentError, fn ->
      defmodule Tmp do
        use Raxx.View, random: :foo
      end
    end
  end

  defp lines(text) do
    String.split(text, ~r/\R/)
    |> Enum.reject(fn line -> line == "" end)
  end
end
