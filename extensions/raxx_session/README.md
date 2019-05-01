# Raxx.Session

**Manage HTTP cookies and storage for persistent client sessions.**

[![Hex pm](http://img.shields.io/hexpm/v/raxx_session.svg?style=flat)](https://hex.pm/packages/raxx_session)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

- [Install from hex.pm](https://hex.pm/packages/raxx_session)
- [Documentation available on hexdoc](https://hexdocs.pm/raxx_session)
- [Discuss on slack](https://elixir-lang.slack.com/messages/C56H3TBH8/)

### Extract, Embed, Expire a session

```elixir
defmodule MyApp.Action do
  use Raxx.SimpleServer
  alias Raxx.Session

  def handle_request(request, state) do
    {:ok, session} = Session.extract(request, state.session_config)
    updated_session = # ... processing

    response(:ok)
    |> Session.embed(updated_session, state.session_config)

    # ... something went wrong
    response(:forbidden)
    |> Session.expire(state.session_config)
  end
end
```

Sessions are extract and embedded in their entirety from requests/responses.
A session is just a map where any term can be saved,
although large terms might not work with certain session stores.

**If a session is updated it MUST be embedded in the response,
otherwise the client will send the same previous session.**

### Flash

*Flash protection used the `:_flash` key in a session,
it should not be manipulated directly*

A flash is information that should be shown to a user only once.
`Raxx.Session` provides some simple helpers to working with flashes.

```elixir
defmodule MyApp.Action do
  use Raxx.SimpleServer
  alias Raxx.Session

  def handle_request(%{path: ["set-flash"]}, state) do
    session = %{}
      |> Session.put_flash(:info, "Welcome to flash!")
      |> Session.put_flash(:error, "Welcome to flash!")
    redirect("/show-flash")
    |> Session.embed(session, state.session_config)
  end

  def handle_request(request = %{path: ["show-flash"]}, state) do
    {:ok, session} = Session.extract(request, state.session_config)

    {flashes, session} = Session.pop_flash(session)

    response(:ok)
    |> render(flashes)
    |> Session.embed(session, state.session_config)
  end
end
```

### CSRF Protection

*CSRF protection used the `:_csrf_token` key in a session,
it should not be manipulated directly*

`Raxx.Session.extract/2` is protected against CSRF attacks.
Sessions can be extracted from safe requests.
These are `GET`, `HEAD` or `OPTIONS` requests and they should have no side effect.

Requests with other methods must provide a `csrf_token`.
By default this value is looked for in the `x-csrf-token` header.

If the token is sent to the server in a different manner it can be explicitly passed by using `Raxx.Session.extract/3`.
For example if it is passed in the body of a request

```elixir
{%{"_csrf_token" => token}} = URI.decode(request.body)

{:ok, session} = Raxx.Session.fetch(request, token, config)
```

**A CSRF token should not be sent back to the server as a query parameter.**

### Configuration

```elixir
session_config = Raxx.Session.config(
                    key: "my_session",
                    store: Raxx.Session.SignedCookie,
                    secret_key_base: String.duplicate("squirrel", 8),
                    salt: "epsom"
                  )
```

For all configuration options see `Raxx.Session` or specific stores.

#### Plug sessions

Sessions from Plug applications can be verified in Raxx applications, and visa versa,
if setup with the same configuration.
