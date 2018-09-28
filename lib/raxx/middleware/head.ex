defmodule Raxx.Middleware.Head do
  @moduledoc """
  An example router that allows you to handle HEAD requests with GET handlers
  """

  alias Raxx.Middleware
  alias Raxx.Pipeline

  @behaviour Middleware

  @impl Middleware
  def handle_head(request = %{method: :HEAD}, _config, pipeline) do
    request = %{request | method: :HEAD}
    state = :engage
    {parts, pipeline} = Pipeline.handle_head(request, pipeline)

    parts = modify_response_parts(parts, state)
    {parts, state, pipeline}
  end

  def handle_head(request = %{method: _}, _config, pipeline) do
    {parts, pipeline} = Pipeline.handle_head(request, pipeline)
    {parts, :disengage, pipeline}
  end

  @impl Middleware
  def handle_data(data, state, pipeline) do
    {parts, pipeline} = Pipeline.handle_data(data, pipeline)
    parts = modify_response_parts(parts, state)
    {parts, state, pipeline}
  end

  @impl Middleware
  def handle_tail(tail, state, pipeline) do
    {parts, pipeline} = Pipeline.handle_tail(tail, pipeline)
    parts = modify_response_parts(parts, state)
    {parts, state, pipeline}
  end

  @impl Middleware
  def handle_info(info, state, pipeline) do
    {parts, pipeline} = Pipeline.handle_info(info, pipeline)
    parts = modify_response_parts(parts, state)
    {parts, state, pipeline}
  end

  defp modify_response_parts(parts, :disengage) do
    parts
  end

  defp modify_response_parts(parts, :engage) do
    Enum.flat_map(parts, &do_handle_response_part(&1))
  end

  defp do_handle_response_part(response = %Raxx.Response{}) do
    # the content-length should remain the same
    [%Raxx.Response{response | body: false}]
  end

  defp do_handle_response_part(%Raxx.Data{}) do
    []
  end

  defp do_handle_response_part(%Raxx.Tail{}) do
    []
  end
end
