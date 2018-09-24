defmodule Raxx.MiddlewareTest do
  use ExUnit.Case

  alias Raxx.Middleware

  defmodule HomePage do
    use Raxx.Server

    @impl Raxx.Server
    def handle_request(_request, _state) do
      response(:ok)
      |> set_body("Home page")
    end
  end

  defmodule NoOp do
    @behaviour Middleware

    @impl Middleware
    def handle_head(request, config, pipeline) do
      {parts, pipeline} = Middleware.handle_head(request, pipeline)
      {parts, config, pipeline}
    end

    @impl Middleware
    def handle_data(data, state, pipeline) do
      {parts, pipeline} = Middleware.handle_data(data, pipeline)
      {parts, state, pipeline}
    end

    @impl Middleware
    def handle_tail(tail, state, pipeline) do
      {parts, pipeline} = Middleware.handle_tail(tail, pipeline)
      {parts, state, pipeline}
    end

    @impl Middleware
    def handle_info(message, state, pipeline) do
      {parts, pipeline} = Middleware.handle_info(message, pipeline)
      {parts, state, pipeline}
    end
  end

  test "a couple of NoOp Middlewares don't modify the response of a simple controller" do
    configs = [{NoOp, :irrelevant}, {NoOp, 42}]
    pipeline = Middleware.create_pipeline(configs, HomePage, :controller_initial)

    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_content_length(3)
      |> Raxx.set_body(true)

    assert {[], pipeline} = Middleware.handle_head(request, pipeline)
    assert {[], pipeline} = Middleware.handle_data("abc", pipeline)

    # middleware simplifies "compound" server responses (full responses)
    assert {[head, body, tail], _pipeline} = Middleware.handle_tail([], pipeline)
    assert %Raxx.Response{status: 200, body: true} = head
    assert %Raxx.Data{data: "Home page"} = body
    assert %Raxx.Tail{headers: []} = tail
  end

  defmodule Meddler do
    @behaviour Middleware
    @impl Middleware
    def handle_head(request, config, pipeline) do
      request =
        case Keyword.get(config, :request_header) do
          nil ->
            request

          value ->
            request
            |> Raxx.delete_header("x-request-header")
            |> Raxx.set_header("x-request-header", value)
        end

      {parts, pipeline} = Middleware.handle_head(request, pipeline)
      parts = modify_parts(parts, config)
      {parts, config, pipeline}
    end

    @impl Middleware
    def handle_data(data, config, pipeline) do
      {parts, pipeline} = Middleware.handle_data(data, pipeline)
      parts = modify_parts(parts, config)
      {parts, config, pipeline}
    end

    @impl Middleware
    def handle_tail(tail, config, pipeline) do
      {parts, pipeline} = Middleware.handle_tail(tail, pipeline)
      parts = modify_parts(parts, config)
      {parts, config, pipeline}
    end

    @impl Middleware
    def handle_info(message, config, pipeline) do
      {parts, pipeline} = Middleware.handle_info(message, pipeline)
      parts = modify_parts(parts, config)
      {parts, config, pipeline}
    end

    defp modify_parts(parts, config) do
      Enum.map(parts, &modify_part(&1, config))
    end

    defp modify_part(data = %Raxx.Data{data: contents}, config) do
      case Keyword.get(config, :response_body) do
        nil ->
          data

        replacement when is_binary(replacement) ->
          new_contents =
            String.replace(contents, ~r/./, replacement)
            # make sure it's the same length
            |> String.slice(0, String.length(contents))

          %Raxx.Data{data: new_contents}
      end
    end

    defp modify_part(part, _state) do
      part
    end
  end

  defmodule SpyServer do
    use Raxx.Server
    # this server is deliberately weird to trip up any assumptions
    @impl Raxx.Server
    def handle_head(request, state) do
      send(self(), {__MODULE__, :handle_head, request, state})
      {[], 1}
    end

    def handle_data(data, state) do
      send(self(), {__MODULE__, :handle_data, data, state})

      headers =
        response(:ok)
        |> set_content_length(10)
        |> set_body(true)

      {[headers], state + 1}
    end

    def handle_tail(tail, state) do
      send(self(), {__MODULE__, :handle_tail, tail, state})
      {[data("spy server"), tail([{"x-response-trailer", "spy-trailer"}])], -1 * state}
    end
  end

  test "middlewares can modify the request" do
    configs = [{Meddler, [request_header: "foo"]}, {Meddler, [request_header: "bar"]}]
    pipeline = Middleware.create_pipeline(configs, SpyServer, :controller_initial)

    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_content_length(3)
      |> Raxx.set_body(true)

    assert {[], pipeline} = Middleware.handle_head(request, pipeline)

    assert_receive {SpyServer, :handle_head, server_request, :controller_initial}
    assert %Raxx.Request{} = server_request
    assert "bar" == Raxx.get_header(server_request, "x-request-header")
    assert 3 == Raxx.get_content_length(server_request)

    assert {[headers], pipeline} = Middleware.handle_data("abc", pipeline)
    assert_receive {SpyServer, :handle_data, "abc", 1}
    assert %Raxx.Response{body: true, status: 200} = headers

    assert {[data, tail], pipeline} = Middleware.handle_tail([], pipeline)
    assert_receive {SpyServer, :handle_tail, [], 2}
    assert %Raxx.Data{data: "spy server"} = data
    assert %Raxx.Tail{headers: [{"x-response-trailer", "spy-trailer"}]} == tail
  end

  test "middlewares can modify the response" do
    configs = [{Meddler, [response_body: "foo"]}, {Meddler, [response_body: "bar"]}]
    pipeline = Middleware.create_pipeline(configs, SpyServer, :controller_initial)

    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_content_length(3)
      |> Raxx.set_body(true)

    assert {[], pipeline} = Middleware.handle_head(request, pipeline)

    assert_receive {SpyServer, :handle_head, server_request, :controller_initial}
    assert %Raxx.Request{} = server_request
    assert nil == Raxx.get_header(server_request, "x-request-header")
    assert 3 == Raxx.get_content_length(server_request)

    assert {[headers], pipeline} = Middleware.handle_data("abc", pipeline)
    assert_receive {SpyServer, :handle_data, "abc", 1}
    assert %Raxx.Response{body: true, status: 200} = headers

    assert {[data, tail], pipeline} = Middleware.handle_tail([], pipeline)
    assert_receive {SpyServer, :handle_tail, [], 2}
    assert %Raxx.Data{data: "foofoofoof"} = data
    assert %Raxx.Tail{headers: [{"x-response-trailer", "spy-trailer"}]} == tail
  end

  test "middlewares can \"short circuit\" processing (not call through)" do
    flunk("TODO")
  end

  test "middlewares' state is correctly updated" do
    flunk("TODO")
  end

  test "a pipeline with no middlewares is functional" do
    flunk("TODO")
  end
end
