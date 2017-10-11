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

    routes = for {match, controller} <- actions do
      {resolved_module, []} = Module.eval_quoted(__CALLER__, controller)
      case Code.ensure_compiled(resolved_module) do
        {:module, ^resolved_module} ->
          behaviours = resolved_module.module_info[:attributes]
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
      quote do
        def handle_headers(request = unquote(match), state) do
          case unquote(controller).handle_headers(request, state) do
            {outbound, new_state} ->
              {outbound, {unquote(controller), new_state}}
            response = %{status: _status} ->
              response
          end
        end
      end
    end

    quote location: :keep do
      @impl Raxx.Server
      def handle_request(_request, _config) do
        raise "This callback should never be called in a on #{__MODULE__}."
      end

      @impl Raxx.Server
      unquote(routes)

      @impl Raxx.Server
      def handle_fragment(fragment, {controller, state}) do
        case controller.handle_fragment(fragment, state) do
          {outbound, new_state} ->
            {outbound, {controller, new_state}}
          response = %{status: _status} ->
            response
        end
      end

      @impl Raxx.Server
      def handle_trailers(trailers, {controller, state}) do
        case controller.handle_trailers(trailers, state) do
          {outbound, new_state} ->
            {outbound, {controller, new_state}}
          response = %{status: _status} ->
            response
        end
      end

      @impl Raxx.Server
      def handle_info(message, {controller, state}) do
        case controller.handle_info(message, state) do
          {outbound, new_state} ->
            {outbound, {controller, new_state}}
          response = %{status: _status} ->
            response
        end
      end
    end
  end
end
