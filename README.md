# Raxx

**Interface for HTTP webservers, frameworks and clients.**

[![Hex pm](http://img.shields.io/hexpm/v/raxx.svg?style=flat)](https://hex.pm/packages/raxx)
[![Build Status](https://secure.travis-ci.org/CrowdHailer/raxx.svg?branch=master
"Build Status")](https://travis-ci.org/CrowdHailer/raxx)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

- [Install from hex.pm](https://hex.pm/packages/raxx)
- [Documentation available on hexdoc](https://hexdocs.pm/raxx)
- [Discuss on slack](https://elixir-lang.slack.com/messages/C56H3TBH8/)

## Extensions

This project includes:

- `Raxx.Router`
- `Raxx.Logger`
- `Raxx.BasicAuth`
- `Raxx.Session.SignedCookie`
- `Raxx.RequestID`

Additional utilities that can be used in Raxx applications.

- [Raxx.MethodOverride](https://github.com/CrowdHailer/raxx_method_override)
- [Raxx.Static](https://github.com/CrowdHailer/raxx_static)
- [Raxx.ApiBlueprint](https://github.com/CrowdHailer/raxx_api_blueprint)

## Getting started

HTTP is an exchange where a client sends a request to a server and expects a response.
At its simplest this can be viewed as follows

```txt
Simple client server exchange.

           request -->
Client ============================================ Server
                                   <-- response
```

#### Simple server

The `HomePage` server implements the simplest HTTP message exchange.
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

#### Running a server

To start a web service a Raxx compatable server is needed.
For example [Ace](https://github.com/crowdhailer/ace).

```elixir
server = HomePage
initial_state = %{}
options = [port: 8080, cleartext: true]

{:ok, pid} = Ace.HTTP.Service.start_link({server, initial_state}, options)
```

Visit [http://localhost:8080](http://localhost:8080).

#### Stateful server

The `LongPoll` server is stateful.
After receiving a complete request this server has to wait for extra input before sending a response to the client.

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
- *A long lived server needs to return two things; the message parts to send, in this case nothing `[]`;
  and the new state of the server, in this case no change `state`.*
- *The `initial_state` is configured when the server is started.*

#### Streaming

Any client server exchange is actually a stream of information in either direction.
`Raxx.Server` provides callbacks to proccess parts of a stream as they are received.

```txt
Detailed view of client server exchange.

           tail | data(1+) | head(request) -->
Client ============================================ Server
           <-- head(response) | data(1+) | tail
```
- *The body of a request or a response, is the combination of all data parts sent.*

#### Server streaming

The `SubscribeToMessages` server streams its response.
The server will send the head of the response upon receiving the request.
Data is sent to the client, as part of the body, when it becomes available.
The response is completed when the chatroom sends a `:closed` message.

```elixir
defmodule SubscribeToMessages do
  use Raxx.Server

  @impl Raxx.Server
  def handle_head(%{method: :GET, path: ["messages"]}, state) do
    {:ok, _} = ChatRoom.join()
    outbound = response(:ok)
    |> set_header("content-type", "text/plain")
    |> set_body(true)

    {[outbound], state}
  end

  @impl Raxx.Server
  def handle_info({ChatRoom, :closed}, state) do
    outbound = tail()

    {[outbound], state}
  end

  def handle_info({ChatRoom, data}, state) do
    outbound = data(data)

    {[outbound], state}
  end
end
```
- *Using `set_body(true)` marks that the response has a body that it is not yet known.*
- *A stream must have a tail to complete, metadata added here will be sent as trailers.*

#### Client streaming

The `Upload` server writes data to a file as it is received.
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
  def handle_data(data, state = {:file, device}) do
    IO.write(device, data)
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
  `handle_data` will be invoked as each part arrives.
  An application should never assume how a body will be broken into data parts.*

#### Router

The `Raxx.Router` can be used to match requests to specific server modules.

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

#### Logger

The `Raxx.Logger` can be used in any raxx server module to add basic logs.
The format of the logs matches the format of the basic Plug logger.
