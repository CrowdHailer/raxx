defmodule Raxx.RouterTest do
  use ExUnit.Case

  defmodule HomePage do
    use Raxx.SimpleServer

    @impl Raxx.SimpleServer
    def handle_request(_request, _state) do
      response(:ok)
      |> set_body("Home page")
    end
  end

  defmodule UsersPage do
    use Raxx.SimpleServer

    @impl Raxx.SimpleServer
    def handle_request(_request, _state) do
      response(:ok)
      |> set_body("Users page")
    end
  end

  defmodule UserPage do
    use Raxx.SimpleServer

    @impl Raxx.SimpleServer
    def handle_request(%{path: ["users", id]}, _state) do
      response(:ok)
      |> set_body("User page #{id}")
    end
  end

  defmodule CreateUser do
    use Raxx.SimpleServer

    @impl Raxx.SimpleServer
    def handle_request(%{body: body}, _state) do
      response(:created)
      |> set_body("User created #{body}")
    end
  end

  defmodule NotFoundPage do
    use Raxx.SimpleServer

    @impl Raxx.SimpleServer
    def handle_request(_request, _state) do
      response(:not_found)
      |> set_body("Not found")
    end
  end

  defmodule InvalidReturn do
    use Raxx.SimpleServer

    @impl Raxx.SimpleServer
    def handle_request(_request, _state) do
      :foo
    end
  end

  describe "original routing API" do
    defmodule OriginalRouter do
      use Raxx.Server

      use Raxx.Router, [
        {%{method: :GET, path: []}, HomePage},
        {%{method: :GET, path: ["users"]}, UsersPage},
        {%{method: :GET, path: ["users", _id]}, UserPage},
        {%{method: :POST, path: ["users"]}, CreateUser},
        {%{method: :GET, path: ["invalid"]}, InvalidReturn},
        {%{method: :POST, path: ["invalid"]}, InvalidReturn},
        {_, NotFoundPage}
      ]
    end

    test "will route to homepage" do
      request = Raxx.request(:GET, "/")
      {[response], _state} = OriginalRouter.handle_head(request, :state)
      assert "Home page" == response.body
    end

    test "will route to fixed segment" do
      request = Raxx.request(:GET, "/users")
      {[response], _state} = OriginalRouter.handle_head(request, :state)
      assert "Users page" == response.body
    end

    test "will route to variable segment path" do
      request = Raxx.request(:GET, "/users/34")
      {[response], _state} = OriginalRouter.handle_head(request, :state)
      assert "User page 34" == response.body
    end

    test "will route on method" do
      request = Raxx.request(:POST, "/users")
      {[response], _state} = OriginalRouter.handle_head(request, :state)
      assert "User created " == response.body
    end

    test "will forward whole request to controller" do
      request =
        Raxx.request(:POST, "/users")
        |> Raxx.set_body(true)

      {[], state} = OriginalRouter.handle_head(request, :state)
      {[], state} = OriginalRouter.handle_data("Bob", state)
      {[response], _state} = OriginalRouter.handle_tail([], state)
      assert "User created Bob" == response.body
    end

    test "will route on catch all" do
      request = Raxx.request(:GET, "/random")
      {[response], _state} = OriginalRouter.handle_head(request, :state)
      assert "Not found" == response.body
    end

    test "adds the action module to logger metadata" do
      request = Raxx.request(:GET, "/")
      _ = OriginalRouter.handle_head(request, :state)
      metadata = Logger.metadata()
      assert "Raxx.RouterTest.HomePage" = Keyword.get(metadata, :"raxx.action")
      assert "%{method: :GET, path: []}" = Keyword.get(metadata, :"raxx.route")
    end

    test "will raise return error if fails to route simple request" do
      request = Raxx.request(:GET, "/invalid")

      assert_raise ReturnError, fn ->
        OriginalRouter.handle_head(request, :state)
      end
    end

    test "will raise return error if fails to route streamed request" do
      request =
        Raxx.request(:POST, "/invalid")
        |> Raxx.set_body(true)

      {[], state} = OriginalRouter.handle_head(request, :state)
      {[], state} = OriginalRouter.handle_data("Bob", state)

      assert_raise ReturnError, fn ->
        OriginalRouter.handle_tail([], state)
      end
    end
  end

  describe "new routing api with middleware" do
    # HEAD MIDDLEA
    defmodule AuthorizationMiddleware do
      use Raxx.Middleware
      alias Raxx.Server

      @impl Raxx.Middleware
      def process_head(request, :pass, next) do
        {parts, next} = Server.handle_head(next, request)
        {parts, :pass, next}
      end

      def process_head(_request, :stop, next) do
        {[Raxx.response(:forbidden)], :stop, next}
      end
    end

    defmodule TestHeaderMiddleware do
      use Raxx.Middleware
      alias Raxx.Server

      @impl Raxx.Middleware
      def process_head(request, state, inner_server) do
        {parts, inner_server} = Server.handle_head(inner_server, request)
        parts = add_header(parts, state)
        {parts, state, inner_server}
      end

      @impl Raxx.Middleware
      def process_data(data, state, inner_server) do
        {parts, inner_server} = Server.handle_data(inner_server, data)
        parts = add_header(parts, state)
        {parts, state, inner_server}
      end

      @impl Raxx.Middleware
      def process_tail(tail, state, inner_server) do
        {parts, inner_server} = Server.handle_tail(inner_server, tail)
        parts = add_header(parts, state)
        {parts, state, inner_server}
      end

      @impl Raxx.Middleware
      def process_info(message, state, inner_server) do
        {parts, inner_server} = Server.handle_info(inner_server, message)
        parts = add_header(parts, state)
        {parts, state, inner_server}
      end

      def add_header([response = %Raxx.Response{} | rest], state) do
        response = Raxx.set_header(response, "x-test", state)
        [response | rest]
      end

      def add_header(parts, _state) when is_list(parts) do
        parts
      end
    end

    defmodule SectionRouter do
      use Raxx.Router

      # Test with HEAD middleware
      section([{TestHeaderMiddleware, "compile-time"}], [
        {%{method: :GET, path: []}, HomePage}
      ])

      section(&private/1, [
        {%{method: :GET, path: ["users"]}, UsersPage},
        {%{method: :GET, path: ["users", _id]}, UserPage},
        {%{method: :POST, path: ["users"]}, CreateUser},
        {%{method: :GET, path: ["invalid"]}, InvalidReturn},
        {%{method: :POST, path: ["invalid"]}, InvalidReturn},
        {_, NotFoundPage}
      ])

      def private(state) do
        [
          {TestHeaderMiddleware, "run-time"},
          {AuthorizationMiddleware, state.authorization}
        ]
      end
    end

    test "will route to homepage" do
      request = Raxx.request(:GET, "/")
      {[response], _state} = SectionRouter.handle_head(request, %{authorization: :pass})
      assert "Home page" == response.body
    end

    test "will route to fixed segment" do
      request = Raxx.request(:GET, "/users")
      {[response], _state} = SectionRouter.handle_head(request, %{authorization: :pass})
      assert "Users page" == response.body
    end

    test "will route to variable segment path" do
      request = Raxx.request(:GET, "/users/34")
      {[response], _state} = SectionRouter.handle_head(request, %{authorization: :pass})
      assert "User page 34" == response.body
    end

    test "will route on method" do
      request = Raxx.request(:POST, "/users")
      {[response], _state} = SectionRouter.handle_head(request, %{authorization: :pass})
      assert "User created " == response.body
    end

    test "will forward whole request to controller" do
      request =
        Raxx.request(:POST, "/users")
        |> Raxx.set_body(true)

      {[], state} = SectionRouter.handle_head(request, %{authorization: :pass})
      {[], state} = SectionRouter.handle_data("Bob", state)
      {[response], _state} = SectionRouter.handle_tail([], state)
      assert "User created Bob" == response.body
    end

    test "will route on catch all" do
      request = Raxx.request(:GET, "/random")
      {[response], _state} = SectionRouter.handle_head(request, %{authorization: :pass})
      assert "Not found" == response.body
    end

    @tag :skip
    test "adds the action module to logger metadata" do
      request = Raxx.request(:GET, "/")
      _ = SectionRouter.handle_head(request, %{authorization: :pass})
      metadata = Logger.metadata()
      assert "Raxx.RouterTest.HomePage" = Keyword.get(metadata, :"raxx.action")
      assert "%{method: :GET, path: []}" = Keyword.get(metadata, :"raxx.route")
    end

    test "will raise return error if fails to route simple request" do
      request = Raxx.request(:GET, "/invalid")

      assert_raise ReturnError, fn ->
        SectionRouter.handle_head(request, %{authorization: :pass})
      end
    end

    test "will raise return error if fails to route streamed request" do
      request =
        Raxx.request(:POST, "/invalid")
        |> Raxx.set_body(true)

      {[], state} = SectionRouter.handle_head(request, %{authorization: :pass})
      {[], state} = SectionRouter.handle_data("Bob", state)

      assert_raise ReturnError, fn ->
        SectionRouter.handle_tail([], state)
      end
    end

    test "middleware as list is applied" do
      request = Raxx.request(:GET, "/")
      {[response], _state} = SectionRouter.handle_head(request, %{authorization: :pass})
      assert "compile-time" == Raxx.get_header(response, "x-test")
    end

    test "middleware as function is applied" do
      request = Raxx.request(:GET, "/users")
      {[response], _state} = SectionRouter.handle_head(request, %{authorization: :pass})
      assert 200 == response.status
      assert "run-time" == Raxx.get_header(response, "x-test")

      request = Raxx.request(:GET, "/users")
      {[response], _state} = SectionRouter.handle_head(request, %{authorization: :stop})
      assert 403 == response.status
      assert "run-time" == Raxx.get_header(response, "x-test")
    end
  end
end
