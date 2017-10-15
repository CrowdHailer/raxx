# Raxx

**Interface for HTTP webservers, frameworks and clients.**

[![Hex pm](http://img.shields.io/hexpm/v/raxx.svg?style=flat)](https://hex.pm/packages/raxx)
[![Build Status](https://secure.travis-ci.org/CrowdHailer/raxx.svg?branch=master
"Build Status")](https://travis-ci.org/CrowdHailer/raxx)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

- [Install from hex.pm](https://hex.pm/packages/raxx)
- [Documentation available on hexdoc](https://hexdocs.pm/raxx)

## Getting started

HTTP is an exchange where a client send a request to a server and expects a response.
At its simplest this can be viewed as follows

```
Simple client server exchange.

           request   >
Client ============================================ Server
                                   <   response
```

#### Simple server

This server implements the simplest HTTP message exchange,
The complete response is constructed from the request.

```elixir
defmodule HomePage do
  use Raxx.Server

  @impl Raxx.Server
  def handle_request(%{method: :GET, path: []}, _state) do
    response(:ok)
    |> set_header("content-type", "text/plain")
    |> set_body("Hello, World!")
  end
end
```
- *A request's path is split into segments, so the root "/" becomes `[]`.*
- *The `_state` is a configuration provided when the server was started.*

#### Running a server

To start a web service a Raxx compatable server is needed.
For example [Ace](https://github.com/crowdhailer/ace).

```elixir
server = HomePage
initial_state = %{}
options = [port: 8080, cleartext: true]

{:ok, pid} = Ace.HTTP.Service.start_link({server, initial_state}, options)
```

Visit http://localhost:8080.

#### Stateful server

This server is stateful.
After receving a complete request this server has to wait for extra input before sending a response to the client.

```elixir
defmodule LongPoll do
  use Raxx.Server

  @impl Raxx.Server
  def handle_request(%{method: :GET, path: ["slow"]}, state) do
    Process.send_after(self(), :reply, 30_000)

    {[], state}
  end

  @impl Raxx.Server
  def handle_info(:reply, _state) do
    response(:ok)
    |> set_header("content-type", "text/plain")
    |> set_body("Hello, Thanks for waiting.")
  end
end
```
- *Return tuple in `handle_request` consists of response parts to send, in this case nothing `[]`;
  and the updated state of the server, in this case no change `state`.*

#### Streaming

Any client server exchange is actually a stream of information in either direction.
A Raxx server can act to parts of the request stream as well as send response parts as it is able to.

```
Detailed view of client server exchange.

           tail | body(1+) | head(request)   >
Client ============================================ Server
           <   head(response) | body(1+) | tail
```

#### Server streaming

This server will send the head of the response immediatly.
Data is sent to the client, as part of the body, when it becomes available.
The response is completed when the chatroom sends a `:closed` message.

```elixir
defmodule SubscribeToMessages do
  use Raxx.Server

  @impl Raxx.Server
  def handle_head(%{method: :GET, path: ["messages"]}, state) do
    {:ok, _} = ChatRoom.join()
    outbound = [response(:ok)
    |> set_header("content-type", "text/plain")
    |> set_body(true)]

    {outbound, state}
  end

  @impl Raxx.Server
  def handle_info({ChatRoom, data}, config) do
    outbound = [body(data)]

    {outbound, config}
  end

  def handle_info({ChatRoom, :closed}, config) do
    outbound = [tail([])]

    {outbound, config}
  end
end
```
- *Using `set_body(true)` marks that the response has a body that it is not yet known.*
- *A stream must have a tail to complete, metadata added here will be sent as trailers.*

#### Client streaming

The `Upload` server writes data to a file as it becomes available.
Only once the complete request has been received is a response sent.

```elixir
defmodule Upload do
  use Raxx.Server

  @impl Raxx.Server
  def handle_head(%{method: :PUT, path: ["upload"] body: true}, _state) do
    {:ok, io_device} = File.open("my/path")
    {[], {:file, device}}
  end

  @impl Raxx.Server
  def handle_body(fragment, state = {:file, device}) do
    IO.write(device, fragment)
    {[], state}
  end

  @impl Raxx.Server
  def handle_tail(_trailers, state) do
    response(:see_other)
    |> set_header("location", "/")
  end
end
```
- *A body may arrive split by packets, chunks or frames.
  An application should never assume how a message is broken up*

#### Routing

The `Raxx.Router` will call a server based on a list of patterns that it will match each request against.

```elixir
defmodule MyApp do
  use Raxx.Server

  use Raxx.Router, [
    {%{method: :GET, path: []}, HomePage},
    {%{method: :GET, path: ["slow"]}, LongPoll},
    {%{method: :GET, path: ["messages"]}, SubscribeToMessages},
    {%{method: :PUT, path: ["upload"]}, Upload},
    {_, NotFoundPage}
  ]
end
```

pure
simple is simple
easy to test
extensible building blocks

## Community

- [elixir-lang slack channel](https://elixir-lang.slack.com/messages/C56H3TBH8/)
- [FAQ](FAQ.md)

## Testing

To work with Raxx locally Elixir 1.4 or greater must be [installed](https://elixir-lang.org/install.html).

```
git clone git@github.com:CrowdHailer/raxx.git
cd raxx

mix deps.get
mix test
```
