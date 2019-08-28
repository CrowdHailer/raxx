defmodule Raxx.Data do
  @moduledoc """
  A part of an HTTP messages body.

  *NOTE: There are no guarantees on how a message's body will be divided into data.*
  """

  @typedoc """
  Container for a section of an HTTP message.
  """
  @type t :: %__MODULE__{
          data: iodata
        }

  @enforce_keys [:data]
  defstruct @enforce_keys
end
