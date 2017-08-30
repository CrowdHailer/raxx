defmodule Raxx.Server do
  @moduledoc """
  Callbacks required to implement a Raxx application.

  Large requests raise a number of issues and the current case of reading the whole request before calling the application.
  - If the request can be determined to be invalid from the headers then don't need to read the request.
  - files might be too large.

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
