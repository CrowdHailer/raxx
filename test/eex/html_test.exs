defmodule EEx.HTMlTest do
  use ExUnit.Case, async: true
  import EEx.HTML
  doctest EEx.HTML

  test "escapes HTML" do
    assert escape_to_binary("<script>") == "&lt;script&gt;"
    assert escape_to_binary("html&company") == "html&amp;company"
    assert escape_to_binary("\"quoted\"") == "&quot;quoted&quot;"
    assert escape_to_binary("html's test") == "html&#39;s test"
  end

  test "escapes HTML to iodata" do
    assert iodata_escape("<script>") == "&lt;script&gt;"
    assert iodata_escape("html&company") == "html&amp;company"
    assert iodata_escape("\"quoted\"") == "&quot;quoted&quot;"
    assert iodata_escape("html's test") == "html&#39;s test"
  end

  defp iodata_escape(data) do
    data |> escape_to_iodata() |> IO.iodata_to_binary()
  end
end
