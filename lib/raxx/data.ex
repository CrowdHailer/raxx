defmodule Raxx.Data do
  @moduledoc """
  A part of an HTTP messages body.

  *NOTE: There are no guarantees on how a message's body will be divided into data.*
  """
  @enforce_keys [:data]
  defstruct @enforce_keys
end
