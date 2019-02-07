defmodule Raxx.SimpleServer do
  @moduledoc """
  Server interface for simple `request -> response` interactions.

  *Modules that use Raxx.SimpleServer implement the Raxx.Server behaviour.
  Default implementations are provided for the streaming interface to buffer the request before a single call to `handle_request/2`.*

  ## Example

  Echo the body of a request to the client

      defmodule EchoServer do
        use Raxx.SimpleServer, maximum_body_length: 12 * 1024 * 1024

        def handle_request(%Raxx.Request{method: :POST, path: [], body: body}, _state) do
          response(:ok)
          |> set_header("content-type", "text/plain")
          |> set_body(body)
        end
      end

  ## Options

  - **maximum_body_length** (default 8MB) the maximum sized body that will be automatically buffered.
    For large requests, e.g. file uploads, consider implementing a streaming server.

  """

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

      def handle_data(data, {request, iodata_buffer, state}) do
        iodata_buffer = [data | iodata_buffer]

        if :erlang.iolist_size(iodata_buffer) <= unquote(maximum_body_length) do
          {[], {request, iodata_buffer, state}}
        else
          Raxx.error_response(:payload_too_large)
        end
      end

      def handle_tail([], {request, iodata_buffer, state}) do
        body = :erlang.iolist_to_binary(Enum.reverse(iodata_buffer))
        response = __MODULE__.handle_request(%{request | body: body}, state)

        case response do
          %{body: true} -> raise "Incomplete response"
          _ -> response
        end
      end

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
