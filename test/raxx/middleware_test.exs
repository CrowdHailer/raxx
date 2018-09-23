defmodule Raxx.MiddlewareTest do
  use ExUnit.Case

  alias Raxx.Middleware

  defmodule LateFooBar do
    use Raxx.Server
    # this server is deliberately weird to trip up any assumptions
    @impl Raxx.Server
    def handle_head(_request, _state) do
      {[], 1}
    end

    def handle_data(_data, state) do
      headers =
        response(:ok)
        |> set_content_length(7)
        |> set_body(true)

      {[headers], state + 1}
    end

    def handle_tail(_tail, state) do
      {[data("foo bar"), tail([{"x-trailer", "x-man"}])], -1 * state}
    end
  end

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
      {next, pipeline} = Middleware.handle_head(request, pipeline)
      {next, config, pipeline}
    end

    @impl Middleware
    def handle_data(data, state, pipeline) do
      {next, pipeline} = Middleware.handle_data(data, pipeline)
      {next, state, pipeline}
    end

    @impl Middleware
    def handle_tail(tail, state, pipeline) do
      {next, pipeline} = Middleware.handle_tail(tail, pipeline)
      {next, state, pipeline}
    end

    @impl Middleware
    def handle_info(message, state, pipeline) do
      {next, pipeline} = Middleware.handle_info(message, pipeline)
      {next, state, pipeline}
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
    assert {[response], _pipeline} = Middleware.handle_tail([], pipeline)
    assert %Raxx.Response{status: 200, body: "Home page"} = response
  end
end
