defmodule Raxx.Router do
  @moduledoc """
  Routing for Raxx applications.

  Routes are defined as a match and an action module.
  Standard Elixir pattern matching is used to apply the match to an incoming request.
  An action module another implementation of `Raxx.Server`

  Sections group routes that all have the same middleware.
  Middleware in a section maybe defined as a list,
  this is useful when all configuration is known at compile-time.
  Alternativly an arity 1 function can be used.
  This can be used when middleware require runtime configuration.
  The argument passed to this function is server initial state.

  ## Examples

      defmodule MyRouter do
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

  *The original API is kept for backwards compatibility.
  See [previous docs](https://hexdocs.pm/raxx/0.17.2/Raxx.Router.html) for details.*

  *If the sections DSL does not work for an application it is possible to instead just implement a `route/2` function.*
  """

  @callback route(Raxx.Request.t(), term) :: Raxx.Stack.t()

  @doc false
  defmacro __using__(actions) when is_list(actions) do
    # DEBT Remove this for 1.0 release
    if actions != [] do
      :elixir_errors.warn(__ENV__.line, __ENV__.file, """
      Routes should not be passed as arguments to `use Raxx.Router`.
          Instead make use of the `section/2` macro.
          See documentation in `Raxx.Router` for details
      """)
    end

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
      if Enum.member?(Module.get_attribute(__MODULE__, :behaviour), Raxx.Server) do
        %{file: file, line: line} = __ENV__

        :elixir_errors.warn(__ENV__.line, __ENV__.file, """
        The module `#{inspect(__MODULE__)}` already included the behaviour `Raxx.Server`.
            This is probably use to `use Raxx.Server`,
            this is no longer necessary when implementing a router.
        """)
      else
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
  defmacro section(middlewares, routes) do
    state = quote do: state

    resolved_middlewares =
      case middlewares do
        middlewares when is_list(middlewares) ->
          middlewares

        _ ->
          quote do
            unquote(middlewares).(unquote(state))
          end
      end

    for {match, action} <- routes do
      quote do
        def route(unquote(match), unquote(state)) do
          # Should this verify_implementation for the action/middlewares
          # Perhaps Stack.new should do it
          Raxx.Stack.new(unquote(resolved_middlewares), {unquote(action), unquote(state)})
        end
      end
    end
  end
end
