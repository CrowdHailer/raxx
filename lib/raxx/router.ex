defmodule Raxx.Router do
  @moduledoc """
  Simple router for Raxx applications.

  A router is a list of associations between a request pattern and controller module.
  `Raxx.Router` needs to be used after `Raxx.Server`,
  it is an extension to a standard Raxx.Server.

  Each controller module that is passed requests from `Raxx.Router` are also standalone `Raxx.Server`s.

  *`Raxx.Router` is a deliberatly low level interface that can act as a base for more sophisticated routers.
  `Raxx.Blueprint` part of the [tokumei project](https://hexdocs.pm/tokumei/Raxx.Blueprint.html) is one example.


  ## Examples
  ### Original API

      defmodule MyRouter do
        use Raxx.Server

        use Raxx.Router, [
          {%{method: :GET, path: []}, HomePage},
          {%{method: :GET, path: ["users"]}, UsersPage},
          {%{method: :GET, path: ["users", _id]}, UserPage},
          {%{method: :POST, path: ["users"]}, CreateUser},
          {_, NotFoundPage}
        ]
      end

  ### Sections based API
  *The original API is kept for backwards compatibility.*

      defmodule MyRouter do
        use Raxx.Server

        use Raxx.Router

        section [{Raxx.Logger, level: :debug}], [
          {%{method: :GET, path: ["ping"]}, Ping},
        ]

        section &web/1, [
          {%{method: :GET, path: []}, HomePage},
          {%{method: :GET, path: ["users"]}, UsersPage},
          {%{method: :GET, path: ["users", _id]}, UserPage},
          {%{method: :POST, path: ["users"]}, CreateUser},
          {_, NotFoundPage}
        ]

        def web(state) do
          [
            {Raxx.Logger, level: state.log_level},
            {MyMiddleware, foo: state.foo}
          ]
        end
      end
  """

  @callback route(Raxx.Request.t(), term) :: Raxx.Stack.t()

  @doc false
  defmacro __using__(actions) when is_list(actions) do
    routes =
      for {match, controller} <- actions do
        {resolved_module, []} = Module.eval_quoted(__CALLER__, controller)

        Raxx.Server.verify_implementation!(resolved_module)

        # NOTE use resolved module to include any aliasing
        controller_string = inspect(resolved_module)
        match_string = Macro.to_string(match)

        quote do
          def route(request = unquote(match), state) do
            Logger.metadata("raxx.action": unquote(controller_string))
            Logger.metadata("raxx.route": unquote(match_string))

            middlewares = []
            Raxx.Stack.new(middlewares, {unquote(controller), state})
          end
        end
      end

    quote location: :keep do
      if !Enum.member?(Module.get_attribute(__MODULE__, :behaviour), Raxx.Server) do
        @behaviour Raxx.Server
      end

      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      unquote(routes)

      @impl Raxx.Server
      def handle_head(request, state) do
        stack = route(request, state)
        Raxx.Server.handle_head(stack, request)
      end

      @impl Raxx.Server
      def handle_data(data, stack) do
        Raxx.Server.handle_data(stack, data)
      end

      @impl Raxx.Server
      def handle_tail(trailers, stack) do
        Raxx.Server.handle_tail(stack, trailers)
      end

      @impl Raxx.Server
      def handle_info(message, stack) do
        Raxx.Server.handle_info(stack, message)
      end
    end
  end

  @doc """
  Define a set of routes with a common set of middlewares applied to them.

  The first argument may be a list of middlewares;
  or a function that accepts one argument, the initial state, and returns a list of middleware.

  If all settings for a middleware can be decided at compile-time then a list is preferable.
  """
  defmacro section(stack, routes) do
    state = quote do: state

    middlewares =
      quote do
        case unquote(stack) do
          middlewares when is_list(middlewares) ->
            middlewares

          stack_function when is_function(stack_function, 1) ->
            stack_function.(unquote(state))
        end
      end

    for {match, action} <- routes do
      quote do
        def route(unquote(match), unquote(state)) do
          Raxx.Stack.new(unquote(middlewares), {unquote(action), unquote(state)})
        end
      end
    end
  end
end
