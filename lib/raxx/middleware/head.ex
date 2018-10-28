defmodule Raxx.Middleware.Head do
  @moduledoc """
  An example router that allows you to handle HEAD requests with GET handlers
  """

  alias Raxx.Server
  alias Raxx.Middleware

  @behaviour Middleware

  @impl Middleware
  def process_head(request = %{method: :HEAD}, _config, inner_server) do
    request = %{request | method: :HEAD}
    state = :engage
    {parts, inner_server} = Server.handle_head(inner_server, request)

    parts = modify_response_parts(parts, state)
    {parts, state, inner_server}
  end

  def process_head(request = %{method: _}, _config, inner_server) do
    {parts, inner_server} = Server.handle_head(inner_server, request)
    {parts, :disengage, inner_server}
  end

  @impl Middleware
  def process_data(data, state, inner_server) do
    {parts, inner_server} = Server.handle_data(inner_server, data)
    parts = modify_response_parts(parts, state)
    {parts, state, inner_server}
  end

  @impl Middleware
  def process_tail(tail, state, inner_server) do
    {parts, inner_server} = Server.handle_tail(inner_server, tail)
    parts = modify_response_parts(parts, state)
    {parts, state, inner_server}
  end

  @impl Middleware
  def process_info(info, state, inner_server) do
    {parts, inner_server} = Server.handle_info(inner_server, info)
    parts = modify_response_parts(parts, state)
    {parts, state, inner_server}
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
