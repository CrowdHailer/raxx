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
  """

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
          def handle_head(request = unquote(match), state) do
            Logger.metadata("raxx.action": unquote(controller_string))
            Logger.metadata("raxx.route": unquote(match_string))

            # TODO get the middlewares from the outside
            middlewares = []
            stack = Raxx.Stack.new(middlewares, {unquote(controller), state})

            {outbound, stack} = Raxx.Server.handle_head(stack, request)
            {outbound, stack}
          end
        end
      end

    quote location: :keep do
      @impl Raxx.Server
      unquote(routes)

      @impl Raxx.Server
      def handle_data(data, stack) do
        Raxx.Server.handle_data(stack, data)
      end

      def handle_tail(trailers, stack) do
        Raxx.Server.handle_tail(stack, trailers)
      end

      def handle_info(message, stack) do
        Raxx.Server.handle_info(stack, message)
      end
    end
  end
end
