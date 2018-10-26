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

        case Raxx.Server.verify_implementation(resolved_module) do
          {:ok, _} ->
            :no_op

          {:error, {:not_a_server_module, module}} ->
            raise ArgumentError, "module `#{module}` does not implement `Raxx.Server` behaviour."

          {:error, {:not_a_module, module}} ->
            raise ArgumentError, "module `#{module}` could not be loaded."
        end

        # NOTE use resolved module to include any aliasing
        controller_string = inspect(resolved_module)
        match_string = Macro.to_string(match)

        quote do
          def handle_head(request = unquote(match), state) do
            Logger.metadata("raxx.action": unquote(controller_string))
            Logger.metadata("raxx.route": unquote(match_string))

            {outbound, new_state} = Raxx.Server.handle({unquote(controller), state}, request)
            {outbound, {unquote(controller), new_state}}
          end
        end
      end

    quote location: :keep do
      @impl Raxx.Server
      unquote(routes)

      @impl Raxx.Server
      def handle_data(data, {controller, state}) do
        # TODO add handle_data etc functions from my middleware branch
        {outbound, new_state} = Raxx.Server.handle({controller, state}, Raxx.data(data))
        {outbound, {controller, new_state}}
      end

      @impl Raxx.Server
      def handle_tail(trailers, {controller, state}) do
        {outbound, new_state} = Raxx.Server.handle({controller, state}, Raxx.tail(trailers))
        {outbound, {controller, new_state}}
      end

      @impl Raxx.Server
      def handle_info(message, {controller, state}) do
        {outbound, new_state} = Raxx.Server.handle({controller, state}, message)
        {outbound, {controller, new_state}}
      end
    end
  end
end
