# Getting Started

## Contents
- What is Raxx?
- Why Raxx?
- Introduction
  - Impatient?
  - Prerequisits
- A simple server
  - Hello, World!
  - An Ace service
  - Requests & Responses
- Project structure
  - Hexagonal Architecture
  - The core domain
  - The WWW directory
- Routing
  - parameters
  - halting
  - api blueprint
- Actions
  - control flow
  - error handling
  - Authentication
- Views
  - what is a view
  - Helpers
  - Partials
  - Layouts
  - EExHTML
- Initialization and configuration
  - runtime vs compiletime
- Testing
- Static Files
  - node assets
- Logging
- Sessions
  - Flash Messages

## What is Raxx

Raxx is a toolkit to make web application with Elixir simple.
It is designed to get out of the way and let you develop any kind of application.

## Why Raxx

1. Adaptable/flexible - Lightweight
  A web layer is just one part of your application,
  Raxx makes very few assumptions about how your application is structured
2. Simplicity
  purity request/response just data structures
  Get out the way just write the elixir you know when possible.
3. Power full ecosystem
  Raxx is the foundation and believes in extensibility

Raxx - Specification and Core library
Ace - Server for Raxx applications that supports HTTP/1 and HTTP/2
Raxx.Kit - Generator for bootstraping Raxx applications
^ The  punchline to this guide if you want to set up a way that works for many run
raxx kit example --node-

---

Build Apps that let you enjoy Elixir
Lightweight
Best practices for DDD, Architectrally sound

It is performat.
Because Elixir is performat

## Introduction

In this guide we are going to walk through creating `MyApp`, your app can come second.
`MyApp` is going to revolutionise hospitality.

#### Impatient?

These guides detail all the parts of a Raxx based web application.
Just want to jump in, use `Raxx.Kit` and generate a fully working we application.

#### Prerequisits

These guides assume you have:

1. [erlang and Elixir installed](https://elixir-lang.org/install.html)

  If you can run `mix --version` and see `1.7.0` or greater all should be good.

2. A mix project

  Run `mix new my_app --sup`, update the generated `mix.exs` file as below

```elixir
defmodule MyApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_app,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:ace, "0.17.0"}]
  end
end
```

3. Fetched dependencies

  Run `mix deps.get`, Ace depends on Raxx and so both will be pulled into our project.

## A simple server

### Hello World

```elixir
# lib/my_app.ex
defmodule MyApp do
  use Raxx.Server

  def handle_request(_request, _state) do
    response(:ok)
    |> set_header("content-type", "text/plain")
    |> set_body("Hello, World!")
  end
end
```

This simple server fully specifies our simple application.

### An Ace service

To start, save the updated app code.
Then start an iex session in the project that loads the mix project.

```
$ iex -S mix
iex> Ace.HTTP.Service.start_link({MyApp, []}, port: 8080, cleartext: true)
{:ok, #PID<...>}
```

### Request & Response

The purpose of a web server is to respond to a clients HTTP request with a HTTP response.

All the information from the request is parsed to a `Raxx.Request` struct.
The `handle_request/2` callback must always return a response.

```elixir
# lib/my_app.ex
defmodule MyApp do
  use Raxx.Server
  import EExHTML

  def handle_request(request, _state) do
    name = get_query(request, "name", "World")

    response(:ok)
    |> set_header("content-type", "text/html")
    |> set_body(html())
  end

  def html(name) do
    ~E"""
    <h1>Hello, <%= name %>!</h1>
    """
  end
end
```

*Requests don't have to be converted directly to a Response.
Either can be streamed, handled as parts become available, see the Streaming section for details.*

## Project Structure

Raxx is just a library, so any project structure can be used,
including just a single file as show already.

However as a project gets larger it is useful to have more structure.
This section suggests a way for structuring Raxx applications.

### Hexagonal Architecture

http://alistair.cockburn.us/Hexagonal+architecture

The main purpose of this architecture is to enforce a separation of concerns between the core concern of an application and the delivery mechanisms.

### The core domain

This is what application does, how this is where the good stuff is/
Nothing in this part of the application should depend on a `Raxx.Request` or `Raxx.Response`

### The WWW directory

**Namespace the web layer**
For example `MyApp.WWW`

This is the home for all the code that:

a) translates HTTP requests into actions to apply to the domain
b) translates domain data structures to HTTP responses

```
lib
├── my_app
│   ├── www
```

*Why not Web*

A public web interface may be one of several access points to the core domain.
They may be other interfaces, including other web interfaces,
such as an admin portal or API.

If our first endpoint is `myapp.com` this is the same `www.myapp.com`.

Feel free to choose another name,
another common namespace is `MyApp.API`.

#### Routing

`Raxx.Router` is included in the core project.
This uses the power of Elixir pattern matching to dispatch to action module.

**Raxx Endpoints**
The action module is just another Raxx app,
there is nothing else special about them.

In the case of a very large app they could be another router which does it's own mapping to actions.

THIS IS SOMETHING MOST LIKELY TO CHANGE

#### Actions

An action is an endpoint that handles a HTTP request for a specific route.

##### Namespacing

Because an application might have a lot of actions.
It is usually useful to put them in their own directory.

`lib/my_app/www/actions/sign_up.ex`

##### A Simple Action

*Why `Raxx.Server`, well each action could be started individually as a server.
Only it wouldn't understand all the other requests that your application might get.*

## View Layer

A view transforms a response from the **domain model** to a HTTP response,
i.e. something for the

A view is a module responsible for rendering a template.
(So far this has been the same as our action model, we can extract by making it more explicit)
`Raxx.View` helps create this modules using `.eex` templates.

*EEx (Embedded Elixir) is a way to embed elixir code in a string.*

### A simple view

Add template here

This template makes use of the `user` variable.
We must tell our view to expect this as an argument to the `render` function it will create.

All the variables in a template must be provided as arguments to the view

```elixir
# lib/my_app/actions/show_user.ex
defmodule ShowUser do
  use Raxx.Server
  use Raxx.View, arguments: [:user], template: "show_user.html.eex"

  def handle_request(_request, _response) do
    response(:ok)
    |> render(%{name: "Gary"})
    # set_body
  end
end
```
Our view also creates a render function which knows the mime type

If you wanted could just define the following
```elixir
def render(response, user) do
  response
  |> set_header("content-type", "text/html")
  |> set_body(text(user))
end

def text(user) do
  "Hello, #{user.name}!"
end
```
---

The response function is included by the Server, and render by the view

In this example our action and view are the same module.

This is another way that functional cohesion is promoted.
All the parts of our our application that help with the single task of "showing a user" are grouped together.

Raxx encourages you to keep actions and templates together.

<!-- - `lib/my_app/www/actions/show_user.ex`
- `lib/my_app/www/actions/show_user.html.eex` -->

*In this case we could have not specifiec the template,
Raxx.View would have assumed the template was in a file with the same name, but different extension*


That doesn't mean that you can't have reusable stuff.

Sending JSON is easy, use `Jason`

### Views and Actions

Grouping things by task is encouraged.
However grouping by type (logical cohesion) is easy to achieve.

```elixir
# lib/my_app/actions/show_user.ex
defmodule MyApp.WWW.Actions.ShowUser do
  use Raxx.Server

  def handle_request(_request, _response) do
    response(:ok)
    |> Views.ShowUser.render(%{username: "Gary"})
  end
end
```

```elixir
# lib/my_app/views/show_user.ex
defmodule MyApp.WWW.Views.ShowUser do
  use Raxx.View, arguments: [:user], template: "../templates/show_user.html.eex"
end
```

## Layouts
Try Raxx.Layout

## Partials

A partial, short for partial template, is just a function to render content that is used in a larger template.

```elixir
user_template = """
<img> <%= user.avatar %>
<%= user.username %>
"""
EEx.function_from_string(:defp, :user_partial, user_template, [:user])
```

To use this function in a template it needs to be defined, or imported, in the corresponding view module.
Remember all functions defined in a layout are imported into the view.

## Helpers

To use helpers import a module.

e.g.

```elixir
defmodule MyApp.WWW.Actions.SignUp do
  use Raxx.Server
  use Raxx.View
  import MyApp.WWW.Helpers

  defp my_function do
    "This is also available in the view"
  end
end
```

By default any layout modules, that use `Raxx.Layout`, will be imported in to views derrived from them.

## Assets
After creating a HTML view static assets are a good next section

Static assets can be served using `Raxx.Static`

Static assets are part web interface and so also part of our www directory.
Assets that can be served directly to the client are kept in the public dir.
e.g. `lib/my_app/www/public`

## Control Flow

### Error Handling

A server should send a response every case,

Ace has us covered in case of a crash and will send an internal_server_error.
However we should do better and help the client if they send us bad content.

Raxx doesn't provide any additional utilies for error handling,
as there are several ways to compose code that might fail.

One of these is with but a suggestion I like it `OK`

Needs to come after parametes

### Halting

#### Initialization and configuration

## Logging

Explain about plug
Say be nice to upgrade e.g hanami but not going to.

## Building Assets

Raxx makes it very easy to set up npm to build assets.
This is part of the Raxx.Kit project use the `--node-assets` flag

## Sessions

Writing a session will send header even if nothing has changed.
This is done to update the liveness times but you might not want to do this.

## Flash

Other frameworks do alot of work for this because it's not very HTTPy

Just pop and then save new session if it gets used

use Query strings for flash.
Find nice JS that cleans up clearing the message

### Input Validation

https://blog.lelonek.me/form-objects-in-elixir-6a57cf7c3d30
https://stackoverflow.com/questions/31987989/form-objects-with-elixir-and-phoenix-framework
https://elixirforum.com/t/form-validation-without-ecto/6804/5
https://medium.com/@feymartynov/validating-controller-params-with-ecto-and-plug-in-phoenix-5fe2cf77a224
https://groups.google.com/forum/#!topic/elixir-lang-talk/jn57CaP0Cgs
https://github.com/CargoSense/vex
- has renderers
https://elixirforum.com/t/json-validation-with-defaults/7952
https://medium.com/@QuantLayer/writing-custom-validations-for-ecto-changesets-4971881c7684
https://www.amberbit.com/blog/2017/12/27/ecto-as-elixir-data-casting-and-validation-library/
https://gist.github.com/laserlemon/a87120155f7c4bf18cd5c15213333790
http://blog.plataformatec.com.br/2016/05/ectos-insert_all-and-schemaless-queries/
https://github.com/elixir-ecto/ecto/issues/2558
https://www.mitchellhanberg.com/post/2017/10/23/encoding-ecto-validation-errors-in-phoenix/
https://hexdocs.pm/ecto/Ecto.Changeset.html#traverse_errors/2

## Appendix 1: Single file applications.

Best is a two file application, use `mix.exs` to manage dependency

```elixir
defmodule Single.MixProject do
  use Mix.Project

  def project do
    [
      app: :single,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:ace, "0.16.8"}]
  end
end
```

```elixir
defmodule Server do
  use Ace.HTTP.Service, port: 8080, cleartext: true

  def handle_request(_request, _state) do
    response(:ok)
    |> set_body("Hello, World!")
  end
end

Server.start_link([])
```

`mix run --no-halt server.exs`

---
This is a roadmap issue for Raxx.
Things are loosly order by importance,
there are two general themes, being framwork ready and API stability.
Raxx is not a framwork but I want using it to be compelling when compared to a framework.
Therefore there are several things that might not end up in this project but are still part of getting to 1.0

Good sources of inspiration Hanami, Pyramind, Sinatra

### Improve words around principles

- Functional Cohesion
- No middleware
- HTTP/2 driven, no bulk send file, although individual servers can implement that.

Add documentation sections to the following that just say discouraged and link to principles.

- Authentication middleware.
  Use plain functions and some other composition such as OK
- Before and after callbacks
  find a real example use composition
- Halt,
  just really an early return
- Helpers not so much discouraged just use imports
- Partials, just helpers made from templates. maybe use function from file with EEx inplace.

#### You might not need a framwork

#### Single file applications
This can probably be writen about now.
Maybe consider adding template string option to Raxx view.

#### Views Templates and Actions
explain url scheme with entity/id/action.
explain possibility of redux in the generated project and messages everywhere.



### A solution for form validation.

Quite likely this is Ecto, or similar.
Hopefully I don't build this but just link appropriatly.
