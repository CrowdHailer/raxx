defmodule Raxx.Server do
  @moduledoc """
  Interface to handle server side communication in an HTTP message exchange.

  *Using `Raxx.Server` allows an application to be run on multiple adapters.
  For example [Ace](https://github.com/CrowdHailer/Ace)
  has several adapters for different versions of the HTTP protocol, HTTP/1.x and HTTP/2*

  ## Getting Started

  **Send complete response after receiving complete request.**

      defmodule EchoServer do
        use Raxx.Server

        def handle_request(%Raxx.Request{method: :POST, path: [], body: body}, _state) do
          response(:ok)
          |> set_header("content-type", "text/plain")
          |> set_body(body)
        end
      end


  **Send complete response as soon as request headers are received.**


      defmodule SimpleServer do
        use Raxx.Server

        def handle_head(%Raxx.Request{method: :GET, path: []}, _state) do
          response(:ok)
          |> set_header("content-type", "text/plain")
          |> set_body("Hello, World!")
        end
      end

  **Store data as it is available from a clients request**

      defmodule StreamingRequest do
        use Raxx.Server

        def handle_head(%Raxx.Request{method: :PUT, body: true}, _state) do
          {:ok, io_device} = File.open("my/path")
          {[], {:file, device}}
        end

        def handle_body(body, state = {:file, device}) do
          IO.write(device, body)
          {[], state}
        end

        def handle_tail(_trailers, state) do
          response(:see_other)
          |> set_header("location", "/")
        end
      end

  **Subscribe server to event source and forward notifications to client.**

      defmodule SubscribeToMessages do
        use Raxx.Server

        def handle_head(_request, _state) do
          {:ok, _} = ChatRoom.join()
          response(:ok)
          |> set_header("content-type", "text/plain")
          |> set_body(true)
        end

        def handle_info({ChatRoom, data}, config) do
          {[body(data)], config}
        end
      end

  ### Notes

  - `handle_head/2` will always be called with a request that has body as a boolean.
    For small requests where buffering the whole request is acceptable a simple middleware can be used.
  - Acceptable return values are the same for all callbacks;
    either a `Raxx.Response`, which must be complete or
    a list of message parts and a new state.

  ## Streaming

  `Raxx.Server` defines an interface to stream the body of request and responses.

  This has several advantages:

  - Large payloads do not need to be help in memory
  - Server can push information as it becomes available, using Server Sent Events.
  - If a request has invalid headers then a reply can be set without handling the body.
  - Content can be generated as requested using HTTP/2 flow control

  The body of a Raxx message (Raxx.Request or `Raxx.Response`) may be one of three types:

  - `io_list` - This is the complete body for the message.
  - `:false` - There **is no** body, for example `:GET` requests never have a body.
  - `:true` - There **is** a body, it can be processed as it is received

  ## Server Isolation

  To start an exchange a client sends a request.
  The server, upon receiving this message, sends a reply.
  A logical HTTP exchange consists of a single request and response.

  Methods such as [pipelining](https://en.wikipedia.org/wiki/HTTP_pipelining)
  and [multiplexing](http://qnimate.com/what-is-multiplexing-in-http2/)
  combine multiple logical exchanges onto a single connection.
  This is done to improve performance and is a detail not exposed a server.

  A Raxx server handles a single HTTP exchange.
  Therefore a single connection my have multiple servers each isolated in their own process.

  ## Termination

  An exchange can be stopped early by terminating the server process.
  Support for early termination is not consistent between versions of HTTP.

  - HTTP/2: server exit with reason `:normal`, stream reset with error `CANCEL`.
  - HTTP/2: server exit any other reason, stream reset with error `INTERNAL_ERROR`.
  - HTTP/1.x: server exit with any reason, connection is closed.

  `Raxx.Server` does not provide a terminate callback.
  Any cleanup that needs to be done from an aborted exchange should be handled by monitoring the server process.
  """

  @typedoc """
  State of application server.

  Original value is the configuration given when starting the raxx application.
  """
  @type state :: any()

  @typedoc """
  Set of all components that make up a message to or from server.
  """
  @type message_part :: Raxx.Request.t() | Raxx.Response.t() | Raxx.Data.t() | Raxx.Tail.t()

  @typedoc """
  Possible return values instructing server to send client data and update state if appropriate.
  """
  @type return :: {[message_part], state} | Raxx.Response.t()

  @doc """
  Called with a complete request once all the data parts of a body are received.

  Passed a `Raxx.Request` and server configuration.
  Note the value of the request body will be a string.

  This callback will never be called if handle_head/handle_body/handle_tail are overwritten.
  """
  @callback handle_request(Raxx.Request.t(), state()) :: return

  @doc """
  Called once when a client starts a stream,

  Passed a `Raxx.Request` and server configuration.
  Note the value of the request body will be a boolean.

  This callback can be relied upon to execute before any other callbacks
  """
  @callback handle_head(Raxx.Request.t(), state()) :: return

  @doc """
  Called every time data from the request body is received
  """
  @callback handle_data(binary(), state()) :: return

  @doc """
  Called once when a request finishes.

  This will be called with an empty list of headers is request is completed without trailers.
  """
  @callback handle_tail([{binary(), binary()}], state()) :: return

  @doc """
  Called for all other messages the server may recieve
  """
  @callback handle_info(any(), state()) :: return

  defmacro __using__(_opts) do
    quote do
      import Raxx
      alias Raxx.{Request, Response}
      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def handle_request(_request, _state) do
        home_page = Raxx.html_escape("<h1>Home Page</h1>")
        not_found_page = Raxx.html_escape("<h1>Ooops! Page not found.</h1>")

        Raxx.response(:ok)
        |> Raxx.set_header("content-type", "text/html")
        |> Raxx.set_body("""
           <h1>Welcome to Raxx</h1>
           <p>Get started with your web application.</p>
           <pre>
           defmodule #{Macro.to_string(__MODULE__)} do
             use #{Macro.to_string(unquote(__MODULE__))}

             @impl #{Macro.to_string(unquote(__MODULE__))}
             def handle_request(%{method: :GET, path: []}, _state) do
               Raxx.response(:ok)
               |> Raxx.set_header("content-type", "text/html")
               |> Raxx.set_body(#{home_page})
             end

             def handle_request(_request, _state) do
               Raxx.response(:not_found)
               |> Raxx.set_header("content-type", "text/html")
               |> Raxx.set_body(#{not_found_page})
             end
           end
           </pre>
           <p>See <a href="https://hexdocs.pm/raxx/Raxx.Server.html">documentation</a> for full details.</p>
           """)
      end

      @impl unquote(__MODULE__)
      def handle_head(request = %{body: false}, state) do
        response = handle_request(%{request | body: ""}, state)

        case response do
          %{body: true} -> raise "Incomplete response"
          _ -> response
        end
      end

      def handle_head(request = %{body: true}, state) do
        {[], {request, "", state}}
      end

      @impl unquote(__MODULE__)
      def handle_data(data, {request, buffer, state}) do
        {[], {request, buffer <> data, state}}
      end

      @impl unquote(__MODULE__)
      def handle_tail([], {request, body, state}) do
        response = handle_request(%{request | body: body}, state)

        case response do
          %{body: true} -> raise "Incomplete response"
          _ -> response
        end
      end

      @impl unquote(__MODULE__)
      def handle_info(message, state) do
        require Logger

        Logger.warn(
          "#{inspect(self())} received unexpected message in handle_info/2: #{inspect(message)}"
        )

        {[], state}
      end

      defoverridable unquote(__MODULE__)
    end
  end
end
