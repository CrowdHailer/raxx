defmodule Raxx.Pipeline do
  alias Raxx.Server
  alias Raxx.Middleware

  @moduledoc """
  A Pipeline is sequence of middlewares attached to a controller
  """

  @typedoc """
  Container for a pipeline - a sequence of middlewares attached to a controller.

  NOTE: Don't rely on the internal structure of this type. It can be modified
  at an arbitrary moment to improve performance or capabilities.
  """
  # ...and it probably will. The way the pipelines are structured right now
  # they append to the back of the middleware list, which is suboptimal, both when
  # it comes to time and memory. They will probably get rewritten as a tuple
  # (or a tagged tuple for easier debugging)
  @opaque t :: [Middleware.t() | Server.t()]

  @spec create([Middleware.t()], module(), any()) :: t()
  def create(configuration, controller_module, initial_state)
      when is_list(configuration) do
    # TODO change those no match errors into informative exceptions
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
    {parts, new_state} =
      apply(controller_module, function_name, [input, controller_state])
      |> Server.normalize_reaction(controller_state)

    true = is_list(parts)
    # TODO discuss this
    # parts = Raxx.simplify_parts(parts)

    {parts, [{controller_module, new_state}]}
  end

  defp handle_anything(
         input,
         [{middleware_module, middleware_state} | rest_of_the_pipeline],
         function_name
       )
       when is_atom(function_name) do
    {parts, new_state, rest_of_the_pipeline} =
      apply(middleware_module, function_name, [input, middleware_state, rest_of_the_pipeline])

    true = is_list(parts)
    # TODO discuss this
    # parts = Raxx.simplify_parts(parts)

    {parts, [{middleware_module, new_state} | rest_of_the_pipeline]}
  end
end
