defmodule Raxx.StackTest do
  use ExUnit.Case

  alias Raxx.Middleware
  alias Raxx.Stack
  alias Raxx.Server

  defmodule HomePage do
    use Raxx.SimpleServer

    @impl Raxx.SimpleServer
    def handle_request(_request, _state) do
      response(:ok)
      |> set_body("Home page")
    end
  end

  defmodule TrackStages do
    @behaviour Middleware

    @impl Middleware
    def process_head(request, config, inner_server) do
      {parts, inner_server} = Server.handle_head(inner_server, request)
      {parts, {config, :head}, inner_server}
    end

    @impl Middleware
    def process_data(data, {_, prev}, inner_server) do
      {parts, inner_server} = Server.handle_data(inner_server, data)
      {parts, {prev, :data}, inner_server}
    end

    @impl Middleware
    def process_tail(tail, {_, prev}, inner_server) do
      {parts, inner_server} = Server.handle_tail(inner_server, tail)
      {parts, {prev, :tail}, inner_server}
    end

    @impl Middleware
    def process_info(message, {_, prev}, inner_server) do
      {parts, inner_server} = Server.handle_info(inner_server, message)
      {parts, {prev, :info}, inner_server}
    end
  end

  defmodule DefaultMiddleware do
    use Middleware
  end

  test "Default middleware callbacks leave the request and response unmodified" do
    middlewares = [{DefaultMiddleware, :irrelevant}, {DefaultMiddleware, 42}]
    stack = make_stack(middlewares, HomePage, :controller_initial)

    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_content_length(3)
      |> Raxx.set_body(true)

    assert {[], stack} = Server.handle_head(stack, request)
    assert {[], stack} = Server.handle_data(stack, "abc")

    assert {[response], _stack} = Server.handle_tail(stack, [])

    assert %Raxx.Response{
             body: "Home page",
             headers: [{"content-length", "9"}],
             status: 200
           } = response
  end

  defmodule Meddler do
    @behaviour Middleware
    @impl Middleware
    def process_head(request, config, inner_server) do
      request =
        case Keyword.get(config, :request_header) do
          nil ->
            request

          value ->
            request
            |> Raxx.delete_header("x-request-header")
            |> Raxx.set_header("x-request-header", value)
        end

      {parts, inner_server} = Server.handle_head(inner_server, request)
      parts = modify_parts(parts, config)
      {parts, config, inner_server}
    end

    @impl Middleware
    def process_data(data, config, inner_server) do
      {parts, inner_server} = Server.handle_data(inner_server, data)
      parts = modify_parts(parts, config)
      {parts, config, inner_server}
    end

    @impl Middleware
    def process_tail(tail, config, inner_server) do
      {parts, inner_server} = Server.handle_tail(inner_server, tail)
      parts = modify_parts(parts, config)
      {parts, config, inner_server}
    end

    @impl Middleware
    def process_info(message, config, inner_server) do
      {parts, inner_server} = Server.handle_info(inner_server, message)
      parts = modify_parts(parts, config)
      {parts, config, inner_server}
    end

    defp modify_parts(parts, config) do
      Enum.map(parts, &modify_part(&1, config))
    end

    defp modify_part(data = %Raxx.Data{data: contents}, config) do
      new_contents = modify_contents(contents, config)
      %Raxx.Data{data | data: new_contents}
    end

    defp modify_part(response = %Raxx.Response{body: contents}, config)
         when is_binary(contents) do
      new_contents = modify_contents(contents, config)
      %Raxx.Response{response | body: new_contents}
    end

    defp modify_part(part, _state) do
      part
    end

    defp modify_contents(contents, config) do
      case Keyword.get(config, :response_body) do
        nil ->
          contents

        replacement when is_binary(replacement) ->
          String.replace(contents, ~r/./, replacement)
          # make sure it's the same length
          |> String.slice(0, String.length(contents))
      end
    end
  end

  defmodule SpyServer do
    use Raxx.Server
    # this server is deliberately weird to trip up any assumptions
    @impl Raxx.Server
    def handle_head(request = %{body: false}, state) do
      send(self(), {__MODULE__, :handle_head, request, state})

      response =
        Raxx.response(:ok) |> Raxx.set_body("SpyServer responds to a request with no body")

      {[response], state}
    end

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
    middlewares = [{Meddler, [request_header: "foo"]}, {Meddler, [request_header: "bar"]}]
    stack = make_stack(middlewares, SpyServer, :controller_initial)

    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_content_length(3)
      |> Raxx.set_body(true)

    assert {[], stack} = Server.handle_head(stack, request)

    assert_receive {SpyServer, :handle_head, server_request, :controller_initial}
    assert %Raxx.Request{} = server_request
    assert "bar" == Raxx.get_header(server_request, "x-request-header")
    assert 3 == Raxx.get_content_length(server_request)

    assert {[headers], stack} = Server.handle_data(stack, "abc")
    assert_receive {SpyServer, :handle_data, "abc", 1}
    assert %Raxx.Response{body: true, status: 200} = headers

    assert {[data, tail], stack} = Server.handle_tail(stack, [])
    assert_receive {SpyServer, :handle_tail, [], 2}
    assert %Raxx.Data{data: "spy server"} = data
    assert %Raxx.Tail{headers: [{"x-response-trailer", "spy-trailer"}]} == tail
  end

  test "middlewares can modify the response" do
    middlewares = [{Meddler, [response_body: "foo"]}, {Meddler, [response_body: "bar"]}]
    stack = make_stack(middlewares, SpyServer, :controller_initial)

    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_content_length(3)
      |> Raxx.set_body(true)

    assert {[], stack} = Server.handle_head(stack, request)

    assert_receive {SpyServer, :handle_head, server_request, :controller_initial}
    assert %Raxx.Request{} = server_request
    assert nil == Raxx.get_header(server_request, "x-request-header")
    assert 3 == Raxx.get_content_length(server_request)

    assert {[headers], stack} = Server.handle_data(stack, "abc")
    assert_receive {SpyServer, :handle_data, "abc", 1}
    assert %Raxx.Response{body: true, status: 200} = headers

    assert {[data, tail], stack} = Server.handle_tail(stack, [])
    assert_receive {SpyServer, :handle_tail, [], 2}
    assert %Raxx.Data{data: "foofoofoof"} = data
    assert %Raxx.Tail{headers: [{"x-response-trailer", "spy-trailer"}]} == tail
  end

  test "middlewares' state is correctly updated" do
    middlewares = [{Meddler, [response_body: "foo"]}, {TrackStages, :config}]
    stack = make_stack(middlewares, SpyServer, :controller_initial)

    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_content_length(3)
      |> Raxx.set_body(true)

    assert {_parts, stack} = Server.handle_head(stack, request)

    assert [{Meddler, [response_body: "foo"]}, {TrackStages, {:config, :head}}] ==
             Stack.get_middlewares(stack)

    assert {SpyServer, 1} == Stack.get_server(stack)

    {_parts, stack} = Server.handle_data(stack, "z")

    assert [{Meddler, [response_body: "foo"]}, {TrackStages, {:head, :data}}] ==
             Stack.get_middlewares(stack)

    assert {SpyServer, 2} == Stack.get_server(stack)

    {_parts, stack} = Server.handle_data(stack, "zz")

    assert [{Meddler, [response_body: "foo"]}, {TrackStages, {:data, :data}}] ==
             Stack.get_middlewares(stack)

    assert {SpyServer, 3} == Stack.get_server(stack)

    {_parts, stack} = Server.handle_tail(stack, [{"x-foo", "bar"}])
    assert [{Meddler, _}, {TrackStages, {:data, :tail}}] = Stack.get_middlewares(stack)
    assert {SpyServer, -3} == Stack.get_server(stack)
  end

  test "a stack with no middlewares is functional" do
    stack = make_stack([], SpyServer, :controller_initial)

    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_content_length(3)
      |> Raxx.set_body(true)

    {stack_result_1, stack} = Server.handle_head(stack, request)
    {stack_result_2, stack} = Server.handle_data(stack, "xxx")
    {stack_result_3, _stack} = Server.handle_tail(stack, [])

    {server_result_1, state} = SpyServer.handle_head(request, :controller_initial)
    {server_result_2, state} = SpyServer.handle_data("xxx", state)
    {server_result_3, _state} = SpyServer.handle_tail([], state)

    assert stack_result_1 == server_result_1
    assert stack_result_2 == server_result_2
    assert stack_result_3 == server_result_3
  end

  defmodule AlwaysForbidden do
    use Middleware

    @impl Middleware
    def process_head(_request, _config, inner_server) do
      response =
        Raxx.response(:forbidden)
        |> Raxx.set_body("Forbidden!")

      {[response], nil, inner_server}
    end
  end

  # This test also checks that the default callbacks from `use` macro can be overridden.
  test "middlewares can \"short circuit\" processing (not call through)" do
    middlewares = [{TrackStages, nil}, {AlwaysForbidden, nil}]
    stack = make_stack(middlewares, SpyServer, :whatever)
    request = Raxx.request(:GET, "/")

    assert {[response], _stack} = Server.handle_head(stack, request)
    assert %Raxx.Response{body: "Forbidden!"} = response

    refute_receive _

    stack = make_stack([{TrackStages, nil}], SpyServer, :whatever)
    assert {[response], _stack} = Server.handle_head(stack, request)
    assert response.body =~ "SpyServer"

    assert_receive {SpyServer, _, _, _}
  end

  defmodule CustomReturn do
    use Raxx.Server
    @impl Raxx.Server
    def handle_head(_request, state) do
      {[:response], state}
    end

    def handle_data(_data, state) do
      {[], state}
    end

    def handle_tail(_tail, state) do
      {[], state}
    end
  end

  defmodule CustomReturnMiddleware do
    @behaviour Middleware

    @impl Middleware
    def process_head(request, _config, inner_server) do
      {parts, inner_server} = Server.handle_head(inner_server, request)
      {process_parts(parts), nil, inner_server}
    end

    @impl Middleware
    def process_data(data, _state, inner_server) do
      {parts, inner_server} = Server.handle_data(inner_server, data)
      {process_parts(parts), nil, inner_server}
    end

    @impl Middleware
    def process_tail(tail, _state, inner_server) do
      {parts, inner_server} = Server.handle_tail(inner_server, tail)
      {process_parts(parts), nil, inner_server}
    end

    @impl Middleware
    def process_info(message, _state, inner_server) do
      {parts, inner_server} = Server.handle_info(inner_server, message)
      {process_parts(parts), nil, inner_server}
    end

    defp process_parts(parts) do
      parts
      |> Raxx.separate_parts()
      |> Enum.map(&process_part/1)
    end

    defp process_part(:response) do
      %Raxx.Response{
        body: "custom",
        headers: [{"content-length", "6"}],
        status: 200
      }
    end

    defp process_part(other) do
      other
    end
  end

  test "servers can, in principle, return custom values to the middleware" do
    stack = make_stack([{CustomReturnMiddleware, nil}], CustomReturn, nil)
    request = Raxx.request(:GET, "/")
    assert {response, _stack} = Server.handle_head(stack, request)
    assert [%Raxx.Response{body: "custom"}] = response
  end

  defp make_stack(middlewares, server_module, server_state) do
    Stack.new(middlewares, {server_module, server_state})
  end
end
