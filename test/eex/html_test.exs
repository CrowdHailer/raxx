defmodule EEx.HTMlTest do
  use ExUnit.Case, async: true
  doctest EEx.HTML

  import EEx.HTML, only: [escape: 1]

  test "escapes HTML" do
    assert escape("<script>") == "&lt;script&gt;"
    assert escape("html&company") == "html&amp;company"
    assert escape("\"quoted\"") == "&quot;quoted&quot;"
    assert escape("html's test") == "html&#39;s test"
  end

  test "escapes HTML to iodata" do
    assert iodata_escape("<script>") == "&lt;script&gt;"
    assert iodata_escape("html&company") == "html&amp;company"
    assert iodata_escape("\"quoted\"") == "&quot;quoted&quot;"
    assert iodata_escape("html's test") == "html&#39;s test"
  end

  defp iodata_escape(data) do
    data |> EEx.HTML.escape_to_iodata() |> IO.iodata_to_binary()
  end
end
