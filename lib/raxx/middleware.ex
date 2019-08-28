defmodule Raxx.Middleware do
  alias Raxx.Server

  @moduledoc """
  A "middleware" is a component that sits between the HTTP server
  such as as [Ace](https://github.com/CrowdHailer/Ace) and a `Raxx.Server` controller.
  The middleware can modify requests request before giving it to the controller and
  modify the controllers response before it's given to the server.

  Oftentimes multiple middlewaress might be attached to a controller and
  function as a single `t:Raxx.Server.t/0` - see `Raxx.Stack` for details.

  The `Raxx.Middleware` provides a behaviour to be implemented by middlewares.

  ## Example

  Traditionally, middlewares are used for a variety of purposes: managing CORS,
  CSRF protection, logging, error handling, and many more. This example shows
  a middleware that given a HEAD request "translates" it to a GET one, hands
  it over to the controller and strips the response body transforms the
  response according to [RFC 2616](https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.13)

  This way the controller doesn't heed to handle the HEAD case at all.

      defmodule Raxx.Middleware.Head do
        alias Raxx.Server
        alias Raxx.Middleware

        @behaviour Middleware

        @impl Middleware
        def process_head(request = %{method: :HEAD}, _config, inner_server) do
          request = %{request | method: :GET}
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
          # the content-length will remain the same
          [%Raxx.Response{response | body: false}]
        end

        defp do_handle_response_part(%Raxx.Data{}) do
          []
        end

        defp do_handle_response_part(%Raxx.Tail{}) do
          []
        end
      end

  Within the callback implementations the middleware should call through
  to the "inner" server and make sure to return its updated state as part
  of the `t:Raxx.Middleware.next/0` tuple.

  In certain situations the middleware might want to short-circuit processing
  of the incoming messages, bypassing the server. In that case, it should not
  call through using `Raxx.Server`'s `handle_*` helper functions and return
  the `inner_server` unmodified.

  ## Gotchas

  ### Info messages forwarding

  As you can see in the above example, the middleware can even modify
  the `info` messages sent to the server and is responsible for forwarding them
  to the inner servers.

  ### Iodata contents

  While much of the time the request body, response body and data chunks will
  be represented with binaries, they can be represented
  as [`iodata`](https://hexdocs.pm/elixir/typespecs.html#built-in-types).

  A robust middleware should handle that.
  """

  @typedoc """
  The behaviour module and state/config of a raxx middleware
  """
  @type t :: {module, state}

  @typedoc """
  State of middleware.
  """
  @type state :: any()

  @typedoc """
  Values returned from the `process_*` callbacks
  """
  @type next :: {[Raxx.part()], state, Server.t()}

  @doc """
  Called once when a client starts a stream,

  The arguments a `Raxx.Request`, the middleware configuration and
  the "inner" server for the middleware to call through to.

  This callback can be relied upon to execute before any other callbacks
  """
  @callback process_head(request :: Raxx.Request.t(), state(), inner_server :: Server.t()) ::
              next()

  @doc """
  Called every time data from the request body is received.
  """
  @callback process_data(binary(), state(), inner_server :: Server.t()) :: next()

  @doc """
  Called once when a request finishes.

  This will be called with an empty list of headers is request is completed without trailers.

  Will not be called at all if the `t:Raxx.Request.t/0` passed to `c:process_head/3` had `body: false`.
  """
  @callback process_tail(trailers :: [{binary(), binary()}], state(), inner_server :: Server.t()) ::
              next()

  @doc """
  Called for all other messages the middleware may recieve.

  The middleware is responsible for forwarding them to the inner server.
  """
  @callback process_info(any(), state(), inner_server :: Server.t()) :: next()

  defmacro __using__(_options) do
    quote do
      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def process_head(request, state, inner_server) do
        {parts, inner_server} = Server.handle_head(inner_server, request)
        {parts, state, inner_server}
      end

      @impl unquote(__MODULE__)
      def process_data(data, state, inner_server) do
        {parts, inner_server} = Server.handle_data(inner_server, data)
        {parts, state, inner_server}
      end

      @impl unquote(__MODULE__)
      def process_tail(tail, state, inner_server) do
        {parts, inner_server} = Server.handle_tail(inner_server, tail)
        {parts, state, inner_server}
      end

      @impl unquote(__MODULE__)
      def process_info(message, state, inner_server) do
        {parts, inner_server} = Server.handle_info(inner_server, message)
        {parts, state, inner_server}
      end

      defoverridable unquote(__MODULE__)
    end
  end

  @doc false
  @spec is_implemented?(module) :: boolean
  def is_implemented?(module) when is_atom(module) do
    # taken from Raxx.Server
    if Code.ensure_compiled?(module) do
      module.module_info[:attributes]
      |> Keyword.get(:behaviour, [])
      |> Enum.member?(__MODULE__)
    else
      false
    end
  end
end
