defmodule Raxx.Middleware do
  alias Raxx.Server

  @typedoc """
  The behaviour module and state/config of a raxx middleware
  """
  @type t :: {module, state}

  @typedoc """
  State of middleware.
  """
  @type state :: Server.state()

  @type next :: {[Raxx.part()], state, Server.t()}

  @doc """
  """
  @callback process_head(Raxx.Request.t(), state(), inner_server :: Server.t()) :: next()

  @doc """
  Called every time data from the request body is received
  """
  @callback process_data(binary(), state(), inner_server :: Server.t()) :: next()

  @doc """
  Called once when a request finishes.

  This will be called with an empty list of headers is request is completed without trailers.
  """
  @callback process_tail([{binary(), binary()}], state(), inner_server :: Server.t()) :: next()

  @doc """
  Called for all other messages the server may recieve
  """
  @callback process_info(any(), state(), inner_server :: Server.t()) :: next()

  @doc false
  @spec is_implemented?(module) :: boolean
  def is_implemented?(module) when is_atom(module) do
    # taken from Raxx.Server
    if Code.ensure_compiled?(module) do
      module.module_info[:attributes]
      |> Keyword.get(:behaviour, [])
      |> Enum.member?(__MODULE__)
    else
      false
    end
  end
end
