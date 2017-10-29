defmodule Raxx.RouterTest do
  use ExUnit.Case

  defmodule HomePage do
    use Raxx.Server

    @impl Raxx.Server
    def handle_request(_request, _state) do
      response(:ok)
      |> set_body("Home page")
    end
  end

  defmodule UsersPage do
    use Raxx.Server

    @impl Raxx.Server
    def handle_request(_request, _state) do
      response(:ok)
      |> set_body("Users page")
    end
  end

  defmodule UserPage do
    use Raxx.Server

    @impl Raxx.Server
    def handle_request(%{path: ["users", id]}, _state) do
      response(:ok)
      |> set_body("User page #{id}")
    end
  end

  defmodule CreateUser do
    use Raxx.Server

    @impl Raxx.Server
    def handle_request(%{body: body}, _state) do
      response(:created)
      |> set_body("User created #{body}")
    end
  end

  defmodule NotFoundPage do
    use Raxx.Server

    @impl Raxx.Server
    def handle_request(_request, _state) do
      response(:not_found)
      |> set_body("Not found")
    end
  end

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

  test "will route to homepage" do
    request = Raxx.request(:GET, "/")
    response = MyRouter.handle_head(request, :state)
    assert "Home page" == response.body
  end

  test "will route to fixed segment" do
    request = Raxx.request(:GET, "/users")
    response = MyRouter.handle_head(request, :state)
    assert "Users page" == response.body
  end

  test "will route to variable segment path" do
    request = Raxx.request(:GET, "/users/34")
    response = MyRouter.handle_head(request, :state)
    assert "User page 34" == response.body
  end

  test "will route on method" do
    request = Raxx.request(:POST, "/users")
    response = MyRouter.handle_head(request, :state)
    assert "User created " == response.body
  end

  test "will forward whole request to controller" do
    request =
      Raxx.request(:POST, "/users")
      |> Raxx.set_body(true)

    {[], state} = MyRouter.handle_head(request, :state)
    {[], state} = MyRouter.handle_data("Bob", state)
    response = MyRouter.handle_tail([], state)
    assert "User created Bob" == response.body
  end

  test "will route on catch all" do
    request = Raxx.request(:GET, "/random")
    response = MyRouter.handle_head(request, :state)
    assert "Not found" == response.body
  end
end
