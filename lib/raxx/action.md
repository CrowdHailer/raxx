## Raxx applications

A Raxx application module has a `handle_request/2` function that takes a `Raxx.Request` and an application environment, as arguments.
For every incomming HTTP connnection `handle_request/2` is called.

The application may indicate to the server that it should respond with a simple HTTP response buy returning a `Raxx.Response` struct.

```elixir
defmodule MySimpleApp do
  def handle_request(_r, _env), do: Raxx.Response.ok()
end
```

Alternativly the the application may indicate that the connection should be upgraded.
In the case of an upgrade the returned upgrade object specifies the communication protocol required.

```elixir
defmodule MyChunkingApp do
  def handle_request(_r, env), do: Raxx.Chunked.upgrade({__MODULE__, env})
  def handle_info(message, _env), do: {:send, "ping"}
end
```

Currently the following upgraded protocols are supported, with others (such as websockets), in development.

- HTTP Chunked
- Server Sent Events

### Raxx.Request

`Raxx.Request`

HTTP requests to a Raxx application are encapsulated in a `Raxx.Request` struct.

```elixir
%Raxx.Request{
  host: "www.example.com",
  path: ["some", "path"],
  ...
}
```

Data can easily be read from the request directly and through pattern matching.
This allows for expressive routing in raxx apps without a routing DSL.
The hello world example is a great example of this.

The `Raxx.Request` module provides additional functionality for inspect the request.
For example inspecting cookies.

```elixir
defmodule Router do
  import Raxx.Request

  def handle_request(request = %{path: ["api" | rest]}, env) do
    ApiRouter.handle_request(%{request | path: rest}, env)
  end

  def handle_request(request = %{path: ["users"], method: method}, _env) do
    case method do
      :GET ->
        query = request.query
        # Get all the users that match a query
      "POST" ->
        data = request.body
        # Create a user with the following data
      "PATCH" ->
        user_id = parse_cookies(request)["user-id"]
        # Update a the details of the user from a cookie session
    end
  end
end
```

To see the details of each request object checkout the [cowboy example](https://github.com/CrowdHailer/raxx/tree/master/example/cowboy_example).

### Raxx.Response

`Raxx.Response`

Any map with the required keys (`:status`, `:headers`, `:body`) can be interpreted by the server as a simple HTTP response.
However it is more usual to return a `Raxx.Response` struct which has sensible defaults for all fields.

Manually creating response structs can be tedious.
The `Raxx.Response` module has several helpers for creating response maps.
This include setting status codes, manipulating cookies

```elixir
defmodule FooRouter do
  alias Raxx.Response
  def handle_request(%{path: ["users"], method: :GET}, _env) do
    Response.ok("All users: Andy, Bethany, Clive")
  end

  def handle_request(%{path: ["users"], method: "POST", body: data}, _env) do
    case MyApp.create_user(data) do
      {:ok, user} -> Response.created("New user #{user}")
      {:error, :already_exists} -> Response.conflict("sorry")
      {:error, :bad_params} -> Response.bad_request("sorry")
      {:error, :database_fail} -> Response.bad_gateway("sorry")
      {:error, _unknown} -> Response.internal_server_error("Well that's weird")
    end
  end

  def handle_request(%{path: ["users"], method: _}, _env) do
    Response.method_not_allowed("Don't do that")
  end

  def handle_request(%{path: ["users", id], method: :GET}, _env) do
    case MyApp.get_user(id) do
      {:ok, user} -> Response.ok("New user #{user}")
      {:error, nil} -> Response.not_found("User unknown")
      {:error, :deleted} -> Response.gone("User deleted")
    end
  end

  def handle_request(_request, _env) do
    Response.not_found("Sorry didn't get that")
  end
end
```
