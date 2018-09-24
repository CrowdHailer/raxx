defmodule Raxx.Middleware do
  alias Raxx.Server

  @typedoc """
  The behaviour module and state of a raxx middleware
  """
  @type t :: {module, state}

  @opaque pipeline :: [t() | Server.t()]

  @typedoc """
  State of middleware.

  Original value is the argument passed in the pipeline setup.
  """
  # aliasing this to Server.state() to help the dialyzer in some cases
  @type state :: Server.state()

  @type next :: {[Raxx.part()], state, pipeline}

  @doc """
  """
  @callback handle_head(Raxx.Request.t(), state(), remaing_pipeline :: pipeline) :: next()

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

  # TODO a better name for this
  @spec create_pipeline(pipeline(), module(), any()) :: pipeline
  def create_pipeline(configuration, controller_module, initial_state)
      when is_list(configuration) do
    true = Server.is_implemented?(controller_module)

    true =
      configuration
      |> Enum.map(fn {module, _args} -> module end)
      |> Enum.map(&is_implemented?/1)
      |> Enum.all?()

    configuration ++ [{controller_module, initial_state}]
  end

  # NOTE those 4 can be rewritten using macros instead of apply for a minor performance increase
  @spec handle_head(Raxx.Request.t(), pipeline) :: {[Raxx.part()], pipeline()}
  def handle_head(request, pipeline) do
    handle_anything(request, pipeline, :handle_head)
  end

  @spec handle_data(binary(), pipeline) :: {[Raxx.part()], pipeline}
  def handle_data(data, pipeline) do
    handle_anything(data, pipeline, :handle_data)
  end

  @spec handle_tail([{binary(), binary()}], pipeline) :: {[Raxx.part()], pipeline}
  def handle_tail(tail, pipeline) do
    handle_anything(tail, pipeline, :handle_tail)
  end

  @spec handle_info(any, pipeline) :: {[Raxx.part()], pipeline}
  def handle_info(message, pipeline) do
    handle_anything(message, pipeline, :handle_info)
  end

  defp handle_anything(input, [{controller_module, controller_state}], function_name)
       when is_atom(function_name) do
    true = Server.is_implemented?(controller_module)

    {parts, new_state} =
      apply(controller_module, function_name, [input, controller_state])
      |> Server.normalize_reaction(controller_state)

    parts = Raxx.simplify_parts(parts)

    {parts, [{controller_module, new_state}]}
  end

  defp handle_anything(
         input,
         [{middleware_module, middleware_state} | rest_of_the_pipeline],
         function_name
       )
       when is_atom(function_name) do
    true = __MODULE__.is_implemented?(middleware_module)

    {parts, new_state, rest_of_the_pipeline} =
      apply(middleware_module, function_name, [input, middleware_state, rest_of_the_pipeline])

    # TODO discuss this
    parts = Raxx.simplify_parts(parts)

    {parts, [{middleware_module, new_state} | rest_of_the_pipeline]}
  end

  @doc false
  @spec normalize_reaction(next(), state()) :: {[Raxx.part()], state()} | no_return
  def normalize_reaction(response = %Raxx.Response{body: true}, _initial_state) do
    raise %ReturnError{return: response}
  end

  def normalize_reaction(response = %Raxx.Response{}, initial_state) do
    {[response], initial_state}
  end

  def normalize_reaction({parts, new_state}, _initial_state) when is_list(parts) do
    {parts, new_state}
  end

  def normalize_reaction(other, _initial_state) do
    raise %ReturnError{return: other}
  end

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
