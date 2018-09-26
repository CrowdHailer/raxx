defmodule Raxx.Middleware do
  alias Raxx.Server

  @typedoc """
  The behaviour module and state of a raxx middleware
  """
  @type t :: {module, state}

  @opaque pipeline :: Raxx.Pipeline.t()

  @typedoc """
  State of middleware.

  Original value is the argument passed in the pipeline setup.
  """
  @type state :: Server.state()
  # @type state :: any()

  @type next :: {[Raxx.part()], state, pipeline}

  @doc """
  """
  @callback handle_head(Raxx.Request.t(), state(), remaining_pipeline :: pipeline) :: next()

  @doc """
  Called every time data from the request body is received
  """
  @callback handle_data(binary(), state(), remaining_pipeline :: pipeline) :: next()

  @doc """
  Called once when a request finishes.

  This will be called with an empty list of headers is request is completed without trailers.
  """
  @callback handle_tail([{binary(), binary()}], state(), remaining_pipeline :: pipeline) :: next()

  @doc """
  Called for all other messages the server may recieve
  """
  @callback handle_info(any(), state(), remaining_pipeline :: pipeline) :: next()

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
