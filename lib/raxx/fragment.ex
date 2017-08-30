defmodule Raxx.Fragment do
  @moduledoc """
  A part of an HTTP messages content

  *NOTE: There are no guarantees made on how a messages content will be fragmented.*
  """
  @enforce_keys [:data, :end_stream]
  defstruct @enforce_keys
end
