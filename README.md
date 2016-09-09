# Raxx: an Elixir webserver interface

## What is Raxx?

1. An interface specification for Elixir webservers and Elixir application.
2. A set of tools to help develop Raxx-compliant web applications

*Raxx is inspired by the [Ruby's Rack interface](http://rack.github.io/) and [Clojure's Ring interface](https://github.com/ring-clojure).*

[Documentation for Raxx is available online](TODO hex)

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

Example of a simple, dynamic Raxx application.
See the [Cowboy example](https://github.com/CrowdHailer/raxx/tree/master/example/cowboy_example) for how to mount a Raxx application to the cowboy server.

### Principles

- Stateless HTTP request fulfill a valuable role in modern applications and will continue to do so, this simple usecase must not be compicated by catering to more advanced communication patterns.
- Use Ruby rack and Clojure ring as inspiration, but be happy to break away from historic CGI-style header names.
- Surface utilities so that it can be used in general HTTP based applications, a RFC6265 module could be used by plug and rack
- Be a good otp citizen, work well in an umbrella app,
- Raxx is designed to be the foundation of a VC (view controller) framework. Other applications in the umbrella should act as the model.
- [Your server as a function](https://monkey.org/~marius/funsrv.pdf)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

1. Add raxx to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:raxx, "~> 0.0.1"}]
    end
    ```

2. Raxx apps/routers needs to be mounted Elixir/erlang server using one of the provided adapters. Instructions for this are found in each adapters README

    - [cowboy](https://github.com/CrowdHailer/raxx/tree/master/example/cowboy_example). Currently just follow example.

## Raxx applications

A Raxx application module has a `handle_request/2` function that takes a `Raxx.Request` and an application environment, as arguments.
For every incomming HTTP connnection `handle_request/2` is called.

*TODO implement a handler behaviour*

The application may indicate to the server that it should respond with a simple HTTP response buy returning a `Raxx.Response` struct.
Alternativly the the application may indicate that the connection should be upgraded, in this case it will return an upgrade object specific to the communication protocol required.

Currently the following upgrades are possible with others (such as websockets), in development.

- Server Sent Events

### Raxx.Request

`Raxx.Request`

With the power of Elixirs pattern matching against maps it is possible to handle request routing without a dsl.
The hello world example is a great example of this.
For request inspection that cannot be achieved by pattern matching the `Raxx.Request` module provides additional functionality.
Such as cookie parsing.

```elixir
defmodule Router do
  import Raxx.Request

  def handle_request(request = %{path: ["users"], method: method}) do
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

To see the details of each request object checkout the cowboy example.

*TODO rename the cowboy example to something like, request visualiser*

### Raxx.Response

`Raxx.Response`

Any map with the required keys (`:status`, `:headers`, `:body`) can be interpreted buy the server as a simple HTTP response.
However it is more usual to return a `Raxx.Response` struct which has sensible defaults for all fields.

Manually creating response maps can be tedious.
The `Raxx.Response` module has several helpers for creating response maps.
This include setting status codes, manipulating cookies

```elixir
defmodule FooRouter do
  import Raxx.Response
  def handle_request(%{path: ["users"], method: "GET"}, _env) do
    ok("All users: Andy, Bethany, Clive")
  end

  def handle_request(%{path: ["users"], method: "POST", body: data}, _env) do
    case MyApp.create_user(data) do
      {:ok, user} -> created("New user #{user}")
      {:error, :already_exists} -> conflict("sorry")
      {:error, :bad_params} -> bad_request("sorry")
      {:error, :database_fail} -> bad_gateway("sorry")
      {:error, _unknown} -> internal_server_error("Well that's weird")
    end
  end

  def handle_request(%{path: ["users"], method: _}, _env) do
    method_not_allowed("Don't do that")
  end

  def handle_request(%{path: ["users", id], method: "GET"}, _env) do
    case MyApp.get_user(id) do
      {:ok, user} -> ok("New user #{user}")
      {:error, nil} -> not_found("User unknown")
      {:error, :deleted} -> gone("User deleted")
    end
  end

  def handle_request(_request, _env) do
    not_found("Sorry didn't get that")
  end
end
```

### Raxx Server Sent Events

See sever sent events in examples directory.

```elixir
defmodule ServerSentEvents.Router do
  import Raxx.Response
  # Can't use ServerSentEvents Handler in same module as other Streaming handlers.
  import Raxx.ServerSentEvents

  def handle_request(%{path: [], method: "GET"}, _opts) do
    ok(home_page)
  end

  def handle_request(%{path: ["events"], method: "GET"}, opts) do
    upgrade(opts, __MODULE__)
  end

  def handle_request(_request, _opts) do
    not_found("Page not found")
  end

  def handle_upgrade(_options) do
    Process.send_after(self, 0, 1000)
    event("hello")
  end

  def handle_info(10, _opts) do
    close()
  end
  def handle_info(i, _opts) when rem(i, 2) == 0 do
    Process.send_after(self, i + 1, 1000)
    event(Integer.to_string(i))
  end
  def handle_info(i, _opts) do
    Process.send_after(self, i + 1, 1000)
    no_event
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
- [ ] Any shared functionality with file streaming, long pole.
- [ ] What to do if message handler throws error.

[Link to implementing server in node.js](http://www.html5rocks.com/en/tutorials/eventsource/basics/)

[HTML living standard](https://html.spec.whatwg.org/multipage/comms.html#server-sent-events)

## Contributing

If you have Elixir installed on your machine then you can treat this project as a normal mix project and run tests via `mix test`.

If required a development environment can be created using [Vagrant](www.vagrantup.com).
