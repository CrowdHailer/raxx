defmodule Raxx.PipelineTest do
  use ExUnit.Case

  alias Raxx.Middleware
  alias Raxx.Pipeline

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
      {parts, pipeline} = Pipeline.handle_head(request, pipeline)
      {parts, {config, :head}, pipeline}
    end

    @impl Middleware
    def handle_data(data, {_, prev}, pipeline) do
      {parts, pipeline} = Pipeline.handle_data(data, pipeline)
      {parts, {prev, :data}, pipeline}
    end

    @impl Middleware
    def handle_tail(tail, {_, prev}, pipeline) do
      {parts, pipeline} = Pipeline.handle_tail(tail, pipeline)
      {parts, {prev, :tail}, pipeline}
    end

    @impl Middleware
    def handle_info(message, {_, prev}, pipeline) do
      {parts, pipeline} = Pipeline.handle_info(message, pipeline)
      {parts, {prev, :info}, pipeline}
    end
  end

  test "a couple of NoOp Middlewares don't modify the response of a simple controller" do
    configs = [{NoOp, :irrelevant}, {NoOp, 42}]
    pipeline = Pipeline.create(configs, HomePage, :controller_initial)

    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_content_length(3)
      |> Raxx.set_body(true)

    assert {[], pipeline} = Pipeline.handle_head(request, pipeline)
    assert {[], pipeline} = Pipeline.handle_data("abc", pipeline)

    # middleware simplifies "compound" server responses (full responses)
    assert {[head, body, tail], _pipeline} = Pipeline.handle_tail([], pipeline)
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

      {parts, pipeline} = Pipeline.handle_head(request, pipeline)
      parts = modify_parts(parts, config)
      {parts, config, pipeline}
    end

    @impl Middleware
    def handle_data(data, config, pipeline) do
      {parts, pipeline} = Pipeline.handle_data(data, pipeline)
      parts = modify_parts(parts, config)
      {parts, config, pipeline}
    end

    @impl Middleware
    def handle_tail(tail, config, pipeline) do
      {parts, pipeline} = Pipeline.handle_tail(tail, pipeline)
      parts = modify_parts(parts, config)
      {parts, config, pipeline}
    end

    @impl Middleware
    def handle_info(message, config, pipeline) do
      {parts, pipeline} = Pipeline.handle_info(message, pipeline)
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
    configs = [{Meddler, [request_header: "foo"]}, {Meddler, [request_header: "bar"]}]
    pipeline = Pipeline.create(configs, SpyServer, :controller_initial)

    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_content_length(3)
      |> Raxx.set_body(true)

    assert {[], pipeline} = Pipeline.handle_head(request, pipeline)

    assert_receive {SpyServer, :handle_head, server_request, :controller_initial}
    assert %Raxx.Request{} = server_request
    assert "bar" == Raxx.get_header(server_request, "x-request-header")
    assert 3 == Raxx.get_content_length(server_request)

    assert {[headers], pipeline} = Pipeline.handle_data("abc", pipeline)
    assert_receive {SpyServer, :handle_data, "abc", 1}
    assert %Raxx.Response{body: true, status: 200} = headers

    assert {[data, tail], pipeline} = Pipeline.handle_tail([], pipeline)
    assert_receive {SpyServer, :handle_tail, [], 2}
    assert %Raxx.Data{data: "spy server"} = data
    assert %Raxx.Tail{headers: [{"x-response-trailer", "spy-trailer"}]} == tail
  end

  test "middlewares can modify the response" do
    configs = [{Meddler, [response_body: "foo"]}, {Meddler, [response_body: "bar"]}]
    pipeline = Pipeline.create(configs, SpyServer, :controller_initial)

    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_content_length(3)
      |> Raxx.set_body(true)

    assert {[], pipeline} = Pipeline.handle_head(request, pipeline)

    assert_receive {SpyServer, :handle_head, server_request, :controller_initial}
    assert %Raxx.Request{} = server_request
    assert nil == Raxx.get_header(server_request, "x-request-header")
    assert 3 == Raxx.get_content_length(server_request)

    assert {[headers], pipeline} = Pipeline.handle_data("abc", pipeline)
    assert_receive {SpyServer, :handle_data, "abc", 1}
    assert %Raxx.Response{body: true, status: 200} = headers

    assert {[data, tail], pipeline} = Pipeline.handle_tail([], pipeline)
    assert_receive {SpyServer, :handle_tail, [], 2}
    assert %Raxx.Data{data: "foofoofoof"} = data
    assert %Raxx.Tail{headers: [{"x-response-trailer", "spy-trailer"}]} == tail
  end

  test "middlewares' state is correctly updated" do
    configs = [{Meddler, [response_body: "foo"]}, {NoOp, :config}]
    pipeline = Pipeline.create(configs, SpyServer, :controller_initial)

    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_content_length(3)
      |> Raxx.set_body(true)

    assert {_, pipeline} = Pipeline.handle_head(request, pipeline)
    # NOTE this test breaks the encapsulation of the pipeline,
    # but the alternative would be a bit convoluted
    assert [{Meddler, [response_body: "foo"]}, {NoOp, {:config, :head}}, {SpyServer, 1}] ==
             pipeline

    {_, pipeline} = Pipeline.handle_data("z", pipeline)
    assert [{Meddler, [response_body: "foo"]}, {NoOp, {:head, :data}}, {SpyServer, 2}] == pipeline

    {_, pipeline} = Pipeline.handle_data("zz", pipeline)
    assert [{Meddler, [response_body: "foo"]}, {NoOp, {:data, :data}}, {SpyServer, 3}] == pipeline

    {_, pipeline} = Pipeline.handle_tail([{"x-foo", "bar"}], pipeline)

    assert [{Meddler, _}, {NoOp, {:data, :tail}}, {SpyServer, -3}] = pipeline
  end

  test "a pipeline with no middlewares is functional" do
    pipeline = Pipeline.create([], SpyServer, :controller_initial)

    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_content_length(3)
      |> Raxx.set_body(true)

    {pipeline_result_1, pipeline} = Pipeline.handle_head(request, pipeline)
    {pipeline_result_2, pipeline} = Pipeline.handle_data("xxx", pipeline)
    {pipeline_result_3, _pipeline} = Pipeline.handle_tail([], pipeline)

    {server_result_1, state} = SpyServer.handle_head(request, :controller_initial)
    {server_result_2, state} = SpyServer.handle_data("xxx", state)
    {server_result_3, _state} = SpyServer.handle_tail([], state)

    assert pipeline_result_1 == server_result_1
    assert pipeline_result_2 == server_result_2
    assert pipeline_result_3 == server_result_3
  end

  defmodule AlwaysForbidden do
    @behaviour Middleware

    @impl Middleware
    def handle_head(_request, _config, pipeline) do
      response =
        Raxx.response(:forbidden)
        |> Raxx.set_body("Forbidden!")

      {[response], nil, pipeline}
    end

    @impl Middleware
    def handle_data(_data, _state, pipeline) do
      {[], nil, pipeline}
    end

    @impl Middleware
    def handle_tail(_tail, _state, pipeline) do
      {[], nil, pipeline}
    end

    @impl Middleware
    def handle_info(_message, _state, pipeline) do
      {[], nil, pipeline}
    end
  end

  test "middlewares can \"short circuit\" processing (not call through)" do
    configs = [{NoOp, nil}, {AlwaysForbidden, nil}]
    pipeline = Pipeline.create(configs, SpyServer, :whatever)
    request = Raxx.request(:GET, "/")

    assert {[_head, data, _tail], _pipeline} = Pipeline.handle_head(request, pipeline)
    assert %Raxx.Data{data: "Forbidden!"} == data

    refute_receive _

    pipeline = Pipeline.create([{NoOp, nil}], SpyServer, :whatever)
    assert {[_head, data, _tail], _pipeline} = Pipeline.handle_head(request, pipeline)

    assert data.data =~ "SpyServer"

    assert_receive {SpyServer, _, _, _}
  end
end
