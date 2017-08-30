defmodule Raxx.Trailer do
  @moduledoc """
  A trailer allows the sender to include additional fields at the end of a streamed message.

  *NOTE: There are no guarantees made on how a messages content will be fragmented.*
  """
  @enforce_keys [:headers]
  defstruct @enforce_keys
end
