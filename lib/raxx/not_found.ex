defmodule Raxx.NotFound do
  require EEx
  @eight_MB 8 * 1024 * 1024

  template = Path.join(__DIR__, "./not_found.html.eex")
  EEx.function_from_file(:defp, :not_found_page, template, [:example_module])

  defmacro __using__(options) do
    body = not_found_page(__CALLER__.module)
    {options, []} = Module.eval_quoted(__CALLER__, options)
    maximum_body_length = Keyword.get(options, :maximum_body_length, @eight_MB)

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
        {[], {request, [], state}}
      end

      @impl Raxx.Server
      def handle_data(data, {request, iodata_buffer, state}) do
        iodata_buffer = [data | iodata_buffer]

        if :erlang.iolist_size(iodata_buffer) <= unquote(maximum_body_length) do
          {[], {request, iodata_buffer, state}}
        else
          Raxx.error_response(:payload_too_large)
        end
      end

      @impl Raxx.Server
      def handle_tail([], {request, iodata_buffer, state}) do
        body = :erlang.iolist_to_binary(Enum.reverse(iodata_buffer))
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
