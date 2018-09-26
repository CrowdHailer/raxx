defmodule Raxx.Pipeline do
  alias Raxx.Server
  alias Raxx.Middleware

  @opaque t :: [Middleware.t() | Server.t()]

  @moduledoc """
  A Pipeline is list of middlewares attached to a controller
  """

  @spec create_pipeline([Middleware.t()], module(), any()) :: t()
  def create_pipeline(configuration, controller_module, initial_state)
      when is_list(configuration) do
    true = Server.is_implemented?(controller_module)

    true =
      configuration
      |> Enum.map(fn {module, _args} -> module end)
      |> Enum.map(&Middleware.is_implemented?/1)
      |> Enum.all?()

    configuration ++ [{controller_module, initial_state}]
  end

  # NOTE those 4 can be rewritten using macros instead of apply for a minor performance increase
  @spec handle_head(Raxx.Request.t(), t()) :: {[Raxx.part()], t()}
  def handle_head(request, pipeline) do
    handle_anything(request, pipeline, :handle_head)
  end

  @spec handle_data(binary(), t()) :: {[Raxx.part()], t()}
  def handle_data(data, pipeline) do
    handle_anything(data, pipeline, :handle_data)
  end

  @spec handle_tail([{binary(), binary()}], t()) :: {[Raxx.part()], t()}
  def handle_tail(tail, pipeline) do
    handle_anything(tail, pipeline, :handle_tail)
  end

  @spec handle_info(any, t()) :: {[Raxx.part()], t()}
  def handle_info(message, pipeline) do
    handle_anything(message, pipeline, :handle_info)
  end

  @spec handle_anything(any, t(), :handle_head | :handle_data | :handle_tail | :handle_info) ::
          {[Raxx.part()], t()}
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
    true = Middleware.is_implemented?(middleware_module)

    {parts, new_state, rest_of_the_pipeline} =
      apply(middleware_module, function_name, [input, middleware_state, rest_of_the_pipeline])

    # TODO discuss this
    parts = Raxx.simplify_parts(parts)

    {parts, [{middleware_module, new_state} | rest_of_the_pipeline]}
  end
end
