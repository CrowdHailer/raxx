defmodule Raxx.Router do
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
