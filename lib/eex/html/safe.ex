defprotocol EEx.HTML.Safe do
  @moduledoc """
  Protocol to create safe HTML encoding of datastrutures.
  """
  @fallback_to_any true

  defstruct [:data]

  @doc """
  Converts a term to iodata.

  If this protocol is not implemented it falls back to `String.Chars.to_string/1`
  and handles html escaping.
  """
  def to_iodata(raw)
end

defimpl EEx.HTML.Safe, for: EEx.HTML.Safe do
  def to_iodata(%{data: data}), do: data
end

defimpl EEx.HTML.Safe, for: Any do
  def to_iodata(term), do: String.Chars.to_string(term) |> EEx.HTML.escape_to_iodata()
end

defimpl String.Chars, for: EEx.HTML.Safe do
  def to_string(%{data: data}) do
    IO.iodata_to_binary(data)
  end
end
