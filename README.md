# Raxx

**A Elixir webserver interface, for stateless HTTP.**

Raxx exists to simplify handling the HTTP request-response cycle.
It deliberately does not handle other communication styles that are part of the modern web.

Raxx is inspired by the [Ruby's Rack interface](http://rack.github.io/) and [Clojure's Ring interface](https://github.com/ring-clojure).

Raxx adapters can be mounted alongside other handlers so that websockets et al can be handled by an more appropriate tool, e.g perhaps plug.

## Usage

### Raxx handlers
A Raxx handler is a module that has a call function.
It takes two arguments, a raxx request and an application specific environment.
The return value is a map with three keys, the status, the headers, and the body.

### Minimal

With the power of Elixirs pattern matching against maps it is possible to handle request routing without a dsl.

```elixir
defmodule BasicRouter do
  # handle the root path
  def call(%{path: [], method: "GET"}, _env) do
    %{status: 200, headers: %{}, body: "Hello, World!"}
  end

  # forward to a sub router
  def call(request = %{path: ["api" | rest]}, env) do
    ApiRouter.call(%{request | path: rest}, env)
  end

  # handle a variable segment in path
  def call(%{path: ["greet", name], method: "GET"}, _env) do
    %{status: 200, headers: %{}, body: "Hello, #{name}"}
  end
end
```

Manually creating all these response hashes can be tedious so the Response module has helpers.

```elixir
defmodule FooRouter do
  import Raxx.Response
  def call(%{path: ["users"], method: "GET"}, _env) do
    ok("All user: Andy, Bethany, Clive")
  end

  def call(%{path: ["users"], method: "POST"}, _env) do
    case MyApp.create_user do
      {:ok, user} -> created("New user #{user}")
      {:error, :already_exists} -> conflict("sorry")
      {:error, :bad_params} -> bad_request("sorry")
      {:error, :database_fail} -> bad_gateway("sorry")
      {:error, _unknown} -> internal_server_error("Well thats weird")
    end
  end

  def call(%{path: ["users"], method: _}, _env) do
    method_not_allowed("Don't do that")
  end

  def call(%{path: ["users", id], method: "GET"}, _env) do
    case MyApp.get_user do
      {:ok, user} -> ok("New user #{user}")
      {:error, nil} -> not_found("User unknown")
      {:error, :deleted} -> gone("User deleted")
    end
  end

  def call(_request, _env) do
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

  def call(%{path: [], method: "GET"}, _opts) do
    ok(home_page)
  end

  def call(%{path: ["events"], method: "GET"}, opts) do
    upgrade(opts, __MODULE__)
  end

  def call(_request, _opts) do
    not_found("Page not found")
  end

  def open(_options) do
    Process.send_after(self, 0, 1000)
    event("hello")
  end

  def info(10, _opts) do
    close()
  end
  def info(i, _opts) when rem(i, 2) == 0 do
    Process.send_after(self, i + 1, 1000)
    event(Integer.to_string(i))
  end
  def info(i, _opts) do
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

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add raxx to your list of dependencies in `mix.exs`:

        def deps do
          [{:raxx, "~> 0.0.1"}]
        end

  2. Raxx apps/routers needs to be mounted Elixir/erlang server using one of the provided adapters. Instructions for this are found in each adapters README

    - [cowboy](https://github.com/CrowdHailer/raxx/tree/master/example/cowboy_example). Currently just follow example.


### Principles

- Stateless HTTP request fulfill a valuable role in modern applications and will continue to do so.
- Handling other communication patterns as plug intends to do just adds complexity which is unnecessary on a whole class of applications.
- Use Ruby rack and Clojure ring as inspiration for naming but be happy to break away from historic CGI-style header names.
- Surface utilities so that it can be used in general HTTP based applications
- Only return json if json is asked for.
