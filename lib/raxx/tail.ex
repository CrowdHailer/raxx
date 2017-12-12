defmodule Raxx.Tail do
  @moduledoc """
  A trailer allows the sender to include additional fields at the end of a streamed message.
  """
  @typedoc """
  Container for optional trailers of an HTTP message.
  """
  @type t :: %__MODULE__{
          headers: [{String.t(), String.t()}]
        }

  @enforce_keys [:headers]
  defstruct @enforce_keys
end
