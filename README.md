# Raxx

**A Elixir webserver interface, for stateless HTTP.**

Raxx exists to simplify handling the HTTP request-response cycle.
It deliberately does not handle other communication styles that are part of the modern web.

Raxx is inspired by the [Ruby's Rack interface](http://rack.github.io/) and [Clojure's Ring interface](https://github.com/ring-clojure).

Raxx adapters can be mounted alongside other handlers so that websockets et al can be handled by an more appropriate tool, e.g perhaps plug.

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
