defmodule Raxx.Tail do
  @moduledoc """
  A trailer allows the sender to include additional fields at the end of a streamed message.
  """
  @enforce_keys [:headers]
  defstruct @enforce_keys
end
