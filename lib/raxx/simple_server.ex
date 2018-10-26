defmodule Raxx.SimpleServer do
  @typedoc """
  State of application server.

  Original value is the configuration given when starting the raxx application.
  """
  @type state :: any()

  @doc """
  Called with a complete request once all the data parts of a body are received.

  Passed a `Raxx.Request` and server configuration.
  Note the value of the request body will be a string.
  """
  @callback handle_request(Raxx.Request.t(), state()) :: Raxx.Response.t()

  @eight_MB 8 * 1024 * 1024

  defmacro __using__(options) do
    {options, []} = Module.eval_quoted(__CALLER__, options)
    maximum_body_length = Keyword.get(options, :maximum_body_length, @eight_MB)

    quote do
      @behaviour unquote(__MODULE__)
      import Raxx

      @behaviour Raxx.Server

      # @impl Raxx.Server
      def handle_head(request = %{body: false}, state) do
        response = __MODULE__.handle_request(%{request | body: ""}, state)

        case response do
          %{body: true} -> raise "Incomplete response"
          _ -> response
        end
      end

      def handle_head(request = %{body: true}, state) do
        {[], {request, [], state}}
      end

      # @impl Raxx.Server
      def handle_data(data, {request, iodata_buffer, state}) do
        iodata_buffer = [data | iodata_buffer]

        if :erlang.iolist_size(iodata_buffer) <= unquote(maximum_body_length) do
          {[], {request, iodata_buffer, state}}
        else
          Raxx.error_response(:payload_too_large)
        end
      end

      # @impl Raxx.Server
      def handle_tail([], {request, iodata_buffer, state}) do
        body = :erlang.iolist_to_binary(Enum.reverse(iodata_buffer))
        response = __MODULE__.handle_request(%{request | body: body}, state)

        case response do
          %{body: true} -> raise "Incomplete response"
          _ -> response
        end
      end

      # @impl Raxx.Server
      def handle_info(message, state) do
        require Logger

        Logger.warn(
          "#{inspect(self())} received unexpected message in handle_info/2: #{inspect(message)}"
        )

        {[], state}
      end
    end
  end
end
