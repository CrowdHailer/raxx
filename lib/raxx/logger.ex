defmodule Raxx.Logger do
  @moduledoc """
  Middleware for basic logging in the format:

      GET /index.html
      Sent 200 in 572ms

  May be used in any `Raxx.Server` module.

      use Raxx.Logger, level: :debug

  ## Options

    - `:level` - The log level this middleware will use for request and response information.
      Default is `:info`.
  """
  require Logger

  defmacro __using__(options) do
    {options, []} = Module.eval_quoted(__CALLER__, options)
    level = Keyword.get(options, :level, :info)

    quote do
      @raxx_logger_level unquote(level)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      defoverridable Raxx.Server

      @impl Raxx.Server
      def handle_head(head, config) do

        unquote(__MODULE__).process_head(head, @raxx_logger_level)
        super(head, config)
        |> unquote(__MODULE__).process_response(@raxx_logger_level)
      end

      @impl Raxx.Server
      def handle_data(data, config) do
        super(data, config)
        |> unquote(__MODULE__).process_response(@raxx_logger_level)
      end

      @impl Raxx.Server
      def handle_tail(tail, config) do
        super(tail, config)
        |> unquote(__MODULE__).process_response(@raxx_logger_level)
      end

      @impl Raxx.Server
      def handle_info(message, config) do
        super(message, config)
        |> unquote(__MODULE__).process_response(@raxx_logger_level)
      end
    end
  end

  @doc false
  def process_head(head, level) do
    Logger.log level, fn() ->
      Process.put(unquote(__MODULE__), %{start: System.monotonic_time()})
      [Atom.to_string(head.method), ?\s, Raxx.normalized_path(head)]
    end
  end

  @doc false
  def process_response(response = %Raxx.Response{}, level) do
    log_response(response, level)
    response
  end
  def process_response(reaction = {[response = %Raxx.Response{} | _parts], _state}, level) do
    log_response(response, level)
    reaction
  end
  def process_response(reaction, _level) do
    reaction
  end

  defp log_response(response, level) do
    Logger.log level, fn() ->
      %{start: start} = Process.get(__MODULE__)
      stop = System.monotonic_time()
      diff = System.convert_time_unit(stop - start, :native, :microsecond)

      [response_type(response), ?\s, Integer.to_string(response.status),
      " in ", formatted_diff(diff)]
    end
  end

  defp formatted_diff(diff) when diff > 1000, do: [diff |> div(1000) |> Integer.to_string, "ms"]
  defp formatted_diff(diff), do: [Integer.to_string(diff), "µs"]

  defp response_type(%{body: true}), do: "Chunked"
  defp response_type(_), do: "Sent"
end
