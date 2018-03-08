defmodule Raxx.NotFound do
  require EEx

  template = Path.join(__DIR__, "./not_found.html.eex")
  EEx.function_from_file(:defp, :not_found_page, template, [:example_module])

  defmacro __using__(_opts) do
    body = not_found_page(__CALLER__.module)
    quote do
      @impl Raxx.Server
      def handle_request(_request, _state) do
        Raxx.response(:not_found)
        |> Raxx.set_header("content-type", "text/html")
        |> Raxx.set_body(unquote(body))
      end

      @impl Raxx.Server
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

      @impl Raxx.Server
      def handle_data(data, {request, buffer, state}) do
        {[], {request, buffer <> data, state}}
      end

      @impl Raxx.Server
      def handle_tail([], {request, body, state}) do
        response = handle_request(%{request | body: body}, state)

        case response do
          %{body: true} -> raise "Incomplete response"
          _ -> response
        end
      end

      @impl Raxx.Server
      def handle_info(message, state) do
        require Logger

        Logger.warn(
          "#{inspect(self())} received unexpected message in handle_info/2: #{inspect(message)}"
        )

        {[], state}
      end

      defoverridable Raxx.Server
    end
  end
end
