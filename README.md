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

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add raxx to your list of dependencies in `mix.exs`:

        def deps do
          [{:raxx, "~> 0.0.1"}]
        end

  2. Raxx apps/routers needs to be mounted Elixir/erlang server using one of the provided adapters. Instructions for this are found in each adapters README

    - [cowboy]() TODO for current setup see adapter tests.


### Principles

- Stateless HTTP request fulfill a valuable role in modern applications and will continue to do so.
- Handling other communication patterns as plug intends to do just adds complexity which is unnecessary on a whole class of applications.
- Use Ruby rack and Clojure ring as inspiration for naming but be happy to break away from historic CGI-style header names.
- Surface utilities so that it can be used in general HTTP based applications
