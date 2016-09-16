# Raxx: an Elixir webserver interface

## What is Raxx?

1. An interface specification for Elixir webservers and Elixir application.
2. A set of tools to help develop Raxx-compliant web applications

[Documentation for Raxx is available online](https://hexdocs.pm/raxx)

## Hello, World!

```elixir
defmodule Hello do
  import Raxx.Response

  def handle_request(%{path: []}, _env) do
    ok("Hello, World!")
  end

  def handle_request(%{path: [name]}, _env) do
    ok("Hello, #{name}!")
  end

  def handle_request(%{path: _unknown}, _env) do
    not_found()
  end
end
```

This Raxx app is mounted on the elli server in the [HelloElli](https://github.com/CrowdHailer/raxx/tree/master/example/hello_elli) example.

### Principles

- Stateless HTTP request fulfill a valuable role in modern applications and will continue to do so, this simple usecase must not be compicated by catering to more advanced communication patterns.
- Use Ruby rack and Clojure ring as inspiration, but be happy to break away from historic CGI-style header names.
- Surface utilities so that it can be used in general HTTP based applications, a RFC6265 module could be used by plug and rack
- Be a good otp citizen, work well in an umbrella app,
- Raxx is designed to be the foundation of a VC (view controller) framework. Other applications in the umbrella should act as the model.
- [Your server as a function](https://monkey.org/~marius/funsrv.pdf)
- No support for working with errors, throws, exits. We handle them in debugging because elixir is a dynamic language but they should not be used for routing or responses other than 500.

*Raxx is inspired by the [Ruby's Rack interface](http://rack.github.io/) and [Clojure's Ring interface](https://github.com/ring-clojure).*

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

1. Add raxx to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:raxx, "~> 0.0.1"}]
    end
    ```

2. Raxx apps/routers needs to be mounted Elixir/erlang server using one of the provided adapters. Instructions for this are found in each adapters README

    - [cowboy](https://github.com/CrowdHailer/raxx/tree/master/example/cowboy_example).
    - [elli](https://github.com/CrowdHailer/raxx/tree/master/example/hello_elli).

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
defmodule MyStreamingApp do
  def handle_request(_r, env), do: Raxx.Streaming.upgrade(__MODULE__, env)
  def handle_info(message, _env), do: {:send, "ping"}
end
```

Currently the following upgraded protocols are supported, with others (such as websockets), in development.

- HTTP streaming
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
      "GET" ->
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
  def handle_request(%{path: ["users"], method: "GET"}, _env) do
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

  def handle_request(%{path: ["users", id], method: "GET"}, _env) do
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

### Raxx.Streaming

`Raxx.Streaming`

The HTTP streaming mechanism keeps a request open indefinitely.
A Raxx application that returns a `Raxx.Streaming` struct from a call to `handle_request/2`, is indicating that it wishes to send the response in chunks.
A `Raxx.Streaming` struct encapsulates all the information required to upgrade the connection.

```elixir
%Raxx.Streaming{
  handler: MyHandler,
  environment: :none,
  ...
}
```

A streaming handler must implement a `handle_info/2` callback.
This callback is called everytime the request process recieves a message, taking the message and environment as arguments.

```elixir
defmodule Ping do
  def handler_request(_, _), do: Raxx.Streaming.upgrade(__MODULE__, nil)

  def handle_info({:data, chunk}), do: {:send, chunk}
  def handle_info({_), do: :nosend
end
```


### Raxx.ServerSentEvents

See sever sent events in examples directory.

```elixir
defmodule ServerSentEvents.Router do
  alias Raxx.Response
  alias Raxx.ServerSentEvents, as: SSE

  def handle_request(%{path: [], method: "GET"}, _opts) do
    Response.ok(home_page)
  end

  def handle_request(%{path: ["events"], method: "GET"}, env) do
    Process.send_after(self, 0, 1000)
    SSE.upgrade(__MODULE__, env, %{initial: "hello"})
  end

  def handle_request(_request, _opts) do
    Response.not_found("Page not found")
  end

  # handle_info
  def handle_info(10, _opts) do
    {:send, ""}
  end
  def handle_info(i, _opts) when rem(i, 2) == 0 do
    Process.send_after(self, i + 1, 1000)
    chunk = SSE.Event.new("#{i}", event: "count") |> SSE.Event.to_chunk
    {:send, chunk}
  end
  def handle_info(i, _opts) do
    Process.send_after(self, i + 1, 1000)
    :nosend
  end

  defp home_page do
    """
    The page. see example.
    """
  end
end
```

Some outstanding questions about Server Sent Events functionality.

- [ ] Disallow event of type error.
- [ ] Handle long poll pollyfill.
- [ ] Raxx client.
- [ ] What to do if message handler throws error.

[Link to implementing server in node.js](http://www.html5rocks.com/en/tutorials/eventsource/basics/)

[HTML living standard](https://html.spec.whatwg.org/multipage/comms.html#server-sent-events)

### Raxx.Test

`Raxx.Test`

This module provides helpers for testing Raxx applications.

```elixir
test "hello app says hi" do
  request = Raxx.Test.get("")
  response = MyApp.handle_request(request, :no_env)
  assert 200 = response.status
  assert "Hello, World!" = response.body
end
```

## Contributing

If you have Elixir installed on your machine then you can treat this project as a normal mix project and run tests via `mix test`.

If required a development environment can be created using [Vagrant](www.vagrantup.com).
