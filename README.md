# Raxx: HTTP interface for Elixir

- [Install from hex.pm](https://hex.pm/packages/raxx)
- [Documentation available on hexdoc](https://hexdocs.pm/raxx)

## Features

- Specification of a **pure** interface for webservers and frameworks.
- A simple and powerful library for building HTTP clients and web applications.

## Community

- [elixir-lang slack channel](https://elixir-lang.slack.com/messages/C56H3TBH8/)
- [FAQ](FAQ.md)

## Contributing

Please do.
Reach out in the slack channel to ask questions.

## Testing

To work with Raxx locally Elixir 1.4 or greater must be [installed](https://elixir-lang.org/install.html).

TODO add link to Tokumei page with docker development tips.

```
git clone git@github.com:CrowdHailer/raxx.git
cd raxx

mix deps.get
mix test
```



### Principles

- Stateless HTTP request fulfill a valuable role in modern applications and will continue to do so, this simple usecase must not be compicated by catering to more advanced communication patterns.
- Use Ruby rack and Clojure ring as inspiration, but be happy to break away from historic CGI-style header names.
- Surface utilities so that it can be used in general HTTP based applications, a RFC6265 module could be used by plug and rack
- Be a good otp citizen, work well in an umbrella app,
- Raxx is designed to be the foundation of a VC (view controller) framework. Other applications in the umbrella should act as the model.
- [Your server as a function](https://monkey.org/~marius/funsrv.pdf)
- No support for working with errors, throws, exits. We handle them in debugging because elixir is a dynamic language but they should not be used for routing or responses other than 500.

*Raxx is inspired by the [Ruby's Rack interface](http://rack.github.io/) and [Clojure's Ring interface](https://github.com/ring-clojure).*

#### Streamed Requests

Large requests raise a number of issues and the current case of reading the whole request before calling the application.
- If the request can be determined to be invalid from the headers then don't need to read the request.
- files might be too large.

There are a variety of solutions.
- call application once headers read.
  handle_request -> response | {:stream, state} | {:read, state}
- write upload to file as read.
  This will be at the adapter level.
  Could be configured to go straight to IPFS/S3, I assume that S3 has a rename API call.
  Use a worker to clean up the remote files, both sanitise and delete old
