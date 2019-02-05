defmodule Raxx.Logger do
  @moduledoc """
  Middleware for basic logging in the format:

      GET /index.html Sent 200 in 572ms

  ## Options

    - `:level` - The log level this middleware will use for request and response information.
      Default is `:info`.
  """
  @behaviour Raxx.Middleware
  alias Raxx.Server

  require Logger

  @enforce_keys [:level, :start, :request]
  defstruct @enforce_keys

  def setup(options) do
    level = Keyword.fetch!(options, :level)
    %__MODULE__{level: level, start: nil, request: nil}
  end

  def process_head(request, options, next) when is_list(options) do
    process_head(request, setup(options), next)
  end

  def process_head(request, state = %__MODULE__{}, next) do
    state = %{state | start: System.monotonic_time(), request: request}

    if !Keyword.has_key?(Logger.metadata(), :"raxx.app") do
      {server, _} = Raxx.Stack.get_server(next)
      Logger.metadata("raxx.app": server)
    end

    Logger.metadata("raxx.scheme": request.scheme)
    Logger.metadata("raxx.authority": request.authority)
    Logger.metadata("raxx.method": request.method)
    Logger.metadata("raxx.path": inspect(request.path))
    Logger.metadata("raxx.query": inspect(request.query))

    {parts, next} = Server.handle_head(next, request)
    :ok = handle_parts(parts, state)
    {parts, state, next}
  end

  def process_data(data, state, next) do
    {parts, next} = Server.handle_data(next, data)
    :ok = handle_parts(parts, state)
    {parts, state, next}
  end

  def process_tail(tail, state, next) do
    {parts, next} = Server.handle_tail(next, tail)
    :ok = handle_parts(parts, state)
    {parts, state, next}
  end

  def process_info(info, state, next) do
    {parts, next} = Server.handle_info(next, info)
    :ok = handle_parts(parts, state)
    {parts, state, next}
  end

  defp handle_parts([response = %Raxx.Response{} | _], state) do
    Logger.log(state.level, fn ->
      stop = System.monotonic_time()
      diff = System.convert_time_unit(stop - state.start, :native, :microsecond)

      [
        Atom.to_string(state.request.method),
        ?\s,
        Raxx.normalized_path(state.request),
        ?\s,
        response_type(response),
        ?\s,
        Integer.to_string(response.status),
        " in ",
        formatted_diff(diff)
      ]
    end)
  end

  defp handle_parts(parts, _state) when is_list(parts) do
    :ok
  end

  defp formatted_diff(diff) when diff > 1000, do: [diff |> div(1000) |> Integer.to_string(), "ms"]
  defp formatted_diff(diff), do: [Integer.to_string(diff), "µs"]

  defp response_type(%{body: true}), do: "Chunked"
  defp response_type(_), do: "Sent"
end
