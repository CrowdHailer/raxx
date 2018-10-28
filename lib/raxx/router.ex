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

        case Code.ensure_compiled(resolved_module) do
          {:module, ^resolved_module} ->
            behaviours =
              resolved_module.module_info[:attributes]
              |> Keyword.get(:behaviour, [])

            case Enum.member?(behaviours, Raxx.Server) do
              true ->
                :no_op

              false ->
                raise "module #{Macro.to_string(resolved_module)} should implement behaviour Raxx.Server"
            end

          {:error, :nofile} ->
            raise "module #{Macro.to_string(resolved_module)} is not loaded"
        end

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
            stack_server = Raxx.Stack.server(stack)

            {outbound, stack_server} = Raxx.Server.handle_head(stack_server, request)
            {outbound, stack_server}
          end
        end
      end

    quote location: :keep do
      @impl Raxx.Server
      def handle_request(_request, _state) do
        raise "This callback should never be called in a on #{__MODULE__}."
      end

      @impl Raxx.Server
      unquote(routes)

      @impl Raxx.Server
      def handle_data(data, stack_server) do
        Raxx.Server.handle_data(stack_server, data)
      end

      def handle_tail(trailers, stack_server) do
        Raxx.Server.handle_tail(stack_server, trailers)
      end

      def handle_info(message, stack_server) do
        Raxx.Server.handle_info(stack_server, message)
      end
    end
  end
end
