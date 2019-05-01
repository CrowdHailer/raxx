# Raxx.Session

**Manage HTTP cookies and storage for persistent client sessions.**

[![Hex pm](http://img.shields.io/hexpm/v/raxx_session.svg?style=flat)](https://hex.pm/packages/raxx_session)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

- [Install from hex.pm](https://hex.pm/packages/raxx_session)
- [Documentation available on hexdoc](https://hexdocs.pm/raxx_session)
- [Discuss on slack](https://elixir-lang.slack.com/messages/C56H3TBH8/)

#### Plug sessions

Sessions from Plug applications can be verified in Raxx applications, and visa versa,
if setup with the same configuration.

## Usage

```elixir
{:ok, session} = Raxx.Session.fetch(request, config)
```

`Raxx.Session.fetch` is protected against CSRF.
If the user_token is submitted in the body then it needs to be provided to fetch the session
and it is an unsafe request

```elixir
{:ok, %{_csrf_token: token}} = Jason.decode(request.body)
{:ok, session} = Raxx.Session.fetch(request, token, config)
```

### Unprotected Sessions

Allow you to use non map sessions

```elixir
{:ok, session} = Raxx.Session.Unprotected.fetch(request, config)
```
