defmodule Raxx.Server do
  @moduledoc """
  Interface to handle server side communication in an HTTP message exchange.

  If simple `request -> response` transformation is possible, try `Raxx.SimpleServer`

  *A module implementing `Raxx.Server` is run by an HTTP server.
  For example [Ace](https://github.com/CrowdHailer/Ace)
  can run such a module for both HTTP/1.x and HTTP/2 exchanges*

  ## Getting Started

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

        def handle_data(body, state = {:file, device}) do
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
          |> set_header("content-type", "text/event-stream")
          |> set_body(true)
        end

        def handle_info({ChatRoom, data}, state) do
          {[body(data)], state}
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
  The behaviour and state of a raxx server
  """
  @type t :: {module, state}

  @typedoc """
  State of application server.

  Original value is the configuration given when starting the raxx application.
  """
  @type state :: any()

  @typedoc """
  Possible return values instructing server to send client data and update state if appropriate.
  """
  @type next :: {[Raxx.part()], state} | Raxx.Response.t()

  @doc """
  Called once when a client starts a stream,

  Passed a `Raxx.Request` and server configuration.
  Note the value of the request body will be a boolean.

  This callback can be relied upon to execute before any other callbacks
  """
  @callback handle_head(Raxx.Request.t(), state()) :: next

  @doc """
  Called every time data from the request body is received
  """
  @callback handle_data(binary(), state()) :: next

  @doc """
  Called once when a request finishes.

  This will be called with an empty list of headers is request is completed without trailers.
  """
  @callback handle_tail([{binary(), binary()}], state()) :: next

  @doc """
  Called for all other messages the server may recieve
  """
  @callback handle_info(any(), state()) :: next

  use Raxx.View, template: "server.html.eex", arguments: [:module]

  defmacro __using__(_options) do
    quote do
      @behaviour unquote(__MODULE__)
      import Raxx

      @impl unquote(__MODULE__)
      def handle_head(_request, _state) do
        response(:not_found)
        |> Raxx.Server.render(__MODULE__)
      end

      @impl unquote(__MODULE__)
      def handle_data(data, state) do
        import Logger
        Logger.warn("Received unexpected data: #{inspect(data)}")
        {[], state}
      end

      @impl unquote(__MODULE__)
      def handle_tail(trailers, state) do
        import Logger
        Logger.warn("Received unexpected trailers: #{inspect(trailers)}")
        {[], state}
      end

      @impl unquote(__MODULE__)
      def handle_info(message, state) do
        import Logger
        Logger.warn("Received unexpected message: #{inspect(message)}")
        {[], state}
      end

      defoverridable unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  # DEBT Remove this for 1.0 release
  defmacro __before_compile__(_env) do
    quote do
      # If handle_request is implemented the module may have been created with raxx < 0.17.0
      # In this case a warning is emitted suggesting using Raxx.SimpleServer instead.
      # This warning can be disabled by adding @raxx_safe_server to the module.
      if Module.defines?(__MODULE__, {:handle_request, 2}) and
           !Module.get_attribute(__MODULE__, :raxx_safe_server) do
        %{file: file, line: line} = __ENV__

        :elixir_errors.warn(__ENV__.line, __ENV__.file, """
        The server `#{inspect(__MODULE__)}` implements `handle_request/2.
            In place of `use Raxx.Server` try `use Raxx.SimpleServer.`
            The behaviour Raxx.Server changes in release 0.17.0, see CHANGELOG for details.
        """)
      end
    end
  end

  @doc """
  Execute a server module and current state in response to a new message
  """
  @spec handle(t, term) :: {[Raxx.part()], t}
  def handle({module, state}, request = %Raxx.Request{}) do
    normalize_reaction(module.handle_head(request, state), state)
  end

  def handle({module, state}, %Raxx.Data{data: data}) do
    normalize_reaction(module.handle_data(data, state), state)
  end

  def handle({module, state}, %Raxx.Tail{headers: headers}) do
    normalize_reaction(module.handle_tail(headers, state), state)
  end

  def handle({module, state}, other) do
    normalize_reaction(module.handle_info(other, state), state)
  end

  defp normalize_reaction(response = %Raxx.Response{body: true}, _initial_state) do
    raise %ReturnError{return: response}
  end

  defp normalize_reaction(response = %Raxx.Response{}, initial_state) do
    {[response], initial_state}
  end

  defp normalize_reaction({parts, new_state}, _initial_state) when is_list(parts) do
    {parts, new_state}
  end

  defp normalize_reaction(other, _initial_state) do
    raise %ReturnError{return: other}
  end

  @doc """
  Verify server can be run?

  A runnable server consists of a tuple of server module and initial state.
  The server module must implement this modules behaviour.
  The initial state can be any term

  ## Examples

      # Could just call verify
      iex> Raxx.Server.verify_server({Raxx.ServerTest.DefaultServer, %{}})
      {:ok, {Raxx.ServerTest.DefaultServer, %{}}}

      iex> Raxx.Server.verify_server({GenServer, %{}})
      {:error, {:not_a_server_module, GenServer}}

      iex> Raxx.Server.verify_server({NotAModule, %{}})
      {:error, {:not_a_module, NotAModule}}
  """
  def verify_server({module, term}) do
    case verify_implementation(module) do
      {:ok, _} ->
        {:ok, {module, term}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  def verify_implementation(module) do
    case fetch_behaviours(module) do
      {:ok, behaviours} ->
        if Enum.member?(behaviours, __MODULE__) do
          {:ok, module}
        else
          {:error, {:not_a_server_module, module}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_behaviours(module) do
    case Code.ensure_compiled?(module) do
      true ->
        behaviours =
          module.module_info[:attributes]
          |> Keyword.take([:behaviour])
          |> Keyword.values()
          |> List.flatten()

        {:ok, behaviours}

      false ->
        {:error, {:not_a_module, module}}
    end
  end
end
