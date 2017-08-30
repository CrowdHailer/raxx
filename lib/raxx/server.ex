defmodule Raxx.Server do
  @moduledoc """
  Callbacks required to implement a Raxx application.

  exit normal to cancel stream
  any other exit to send reset with internal error
  """
  @doc """
  Called when a client starts a stream,

  Passed a `Raxx.Request` and state
  """
  @callback handle_headers(any(), any()) :: any()


  @callback handle_fragment(any(), any()) :: any()
  @callback handle_trailers(any(), any()) :: any()

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end
end
