defmodule Raxx.ViewTest do
  use ExUnit.Case

  defmodule DefaultTemplate do
    use Raxx.View, arguments: [:var]
    defp private(), do: "DefaultTemplate"
  end

  defmodule WithLayout do
    use Raxx.View, arguments: [:var], layout: "view_test_layout.html.eex"
    defp private(), do: "WithLayout"
  end

  defmodule AbsoluteTemplate do
    use Raxx.View, arguments: [:var], template: Path.join(__DIR__, "view_test_other.html.eex")
  end

  defmodule RelativeTemplate do
    use Raxx.View, arguments: [:var], template: "view_test_other.html.eex"
  end

  test "Arguments and private module functions are available in templated" do
    assert ["foo", "DefaultTemplate"] = lines("#{DefaultTemplate.html("foo")}")
  end

  test "HTML content is escaped" do
    assert "&lt;p&gt;" = hd(lines("#{DefaultTemplate.html("<p>")}"))
  end

  test "Safe HTML content is not escaped" do
    assert "<p>" = hd(lines("#{DefaultTemplate.html(EExHTML.raw("<p>"))}"))
  end

  test "Render will set content-type and body" do
    response =
      Raxx.response(:ok)
      |> DefaultTemplate.render("bar")

    assert ["bar", "DefaultTemplate"] = lines(response.body)
    assert [{"content-type", "text/html"}, {"content-length", "20"}] = response.headers
  end

  test "View can be rendered within a layout" do
    assert ["LAYOUT", "baz", "WithLayout"] = lines("#{WithLayout.html("baz")}")
  end

  test "Default template can changed" do
    assert ["OTHER", "5"] = lines("#{AbsoluteTemplate.html("5")}")
  end

  test "Template path can be relative to calling file" do
    assert ["OTHER", "5"] = lines("#{RelativeTemplate.html("5")}")
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
    String.split("#{text}", ~r/\R/)
    |> Enum.reject(fn line -> line == "" end)
  end

  defmodule DefaultTemplatePartial do
    import Raxx.View

    partial(:partial, [:var])

    defp private do
      "Default"
    end
  end

  defmodule RelativeTemplatePartial do
    import Raxx.View

    partial(:partial, [:var], template: "other.html.eex")

    defp private do
      "Relative"
    end
  end

  test "Arguments and private funcations are available in the partial template" do
    assert ["5", "Default"] = lines("#{DefaultTemplatePartial.partial("5")}")
  end

  test "HTML content in a partial is escaped" do
    assert ["5", "Default"] = lines("#{DefaultTemplatePartial.partial("5")}")
  end

  test "Partial template path can be relative to calling file" do
    assert ["5", "Relative"] = lines("#{RelativeTemplatePartial.partial("5")}")
  end
end
