# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [1.1.0](https://github.com/CrowdHailer/raxx/tree/1.1.0) - 2019-09-04

### Added

- `Raxx.Request.uri/1` and docs for `Raxx.Request` module.

### Changed

- Usage of `iodata` made more explicit in the docs.

## [1.0.1](https://github.com/CrowdHailer/raxx/tree/1.0.1) - 2019-05-01

### Added

- Typespec added for `Raxx.request_port/2` so that return type is `:inet.port_number` not `integer`.

## [1.0.0](https://github.com/CrowdHailer/raxx/tree/1.0.0) - 2019-04-16

### Removed

- Config option for `:extra_statuses` removed.
- `Raxx.reason_phrase/1` returns `nil` for unknown status code.
- Warnings given when using `Raxx.Server` and `Raxx.Router` in the same module.
- Warnings given for implementing `handle_request/2` in a module using `Raxx.Server`.

## [0.18.1](https://github.com/CrowdHailer/raxx/tree/0.18.1) - 2019-02-19

### Changed

- `Raxx.redirect/2` no longer adds a HTML body. The body can now be set with an option.

### Removed

- EExHTML is no longer a dependency.

## [0.18.0](https://github.com/CrowdHailer/raxx/tree/0.18.0) - 2019-02-07

### Removed

- Warnings to include `raxx_logger` and `raxx_view`.
- `mount` field from `Raxx.Request`.
- `Raxx.BasicAuth` see the BasicAuthentication extension in `Raxx.Kit`.
- `Raxx.Session.SignedCookie` no longer supported, to be added as extension.
- `Raxx.SimpleClient` no longer supported.
- `Raxx.RequestID` no longer supported.

## [0.17.6](https://github.com/CrowdHailer/raxx/tree/0.17.6) - 2019-02-05

### Removed

- `Raxx.View` and `Raxx.Layout` extracted to separate extension project,
  use `{:raxx_view, "~> 0.1.0"}` for backwards compatable api.

### Added

- `Raxx.Context` for passing contextual information about the request/response.

## [0.17.5](https://github.com/CrowdHailer/raxx/tree/0.17.5) - 2019-02-04

### Removed

- `Raxx.Logger` extracted to separate extension project,
  use `{:raxx_logger, "~> 0.1.0"}` for backwards compatable api.

## [0.17.4](https://github.com/CrowdHailer/raxx/tree/0.17.4) - 2019-01-06

### Fixed

- Dialyzer warning from `Raxx.Router.section/2` macro fixed.

## [0.17.3](https://github.com/CrowdHailer/raxx/tree/0.17.3) - 2018-11-22

### Added

- `Raxx.Router.section/2` for defining routes that have a middleware stack.
- Using macro for `Raxx.Middleware` that adds default implementations for each callback.

## [0.17.2](https://github.com/CrowdHailer/raxx/tree/0.17.2) - 2018-11-13

### Added

- Support `eex_html` versions `0.1.x` and `0.2.x`.

## [0.17.1](https://github.com/CrowdHailer/raxx/tree/0.17.1) - 2018-11-01

### Added

- `Raxx.Middleware` to develop composable components for common server functionality.
- `Raxx.Stack` module to combine middlewares are server modules.

## [0.17.0](https://github.com/CrowdHailer/raxx/tree/0.17.0) - 2018-10-28

### Added

- `Raxx.SimpleServer` behaviour for servers that only need a `handle_request/2` callback.
  using `Raxx.SimpleServer` automatically implements `Raxx.Server` so the module can be used in a service.

### Changed

- `use Raxx.Server` issues a warning if the module implements `handle_request/2`,
  it is expected that such servers will make use of the new `Raxx.SimpleServer`.
- `Raxx.set_header/2` raises an `ArgumentError` when setting host headers.
- `ArgumentError` is raised instead of `RuntimeError` in cases of bad headers and body content.
- `Raxx.set_body/2` raises an `ArgumentError` for GET and HEAD requests.

### Removed

- `Raxx.is_application?`, use `Raxx.Server.verify_server` instead.
- `Raxx.verify_application`, use `Raxx.Server.verify_server` instead.
- `Raxx.Server.is_implemented?`, use `Raxx.Server.verify_server` instead.

## [0.16.1](https://github.com/CrowdHailer/raxx/tree/0.16.1) - 2018-09-19

### Fixed

- `Raxx.NotFound` was incorrectly building body for `handle_request` callback.

## [0.16.0](https://github.com/CrowdHailer/raxx/tree/0.16.0) - 2018-09-12

### Added

- `:maximum_body_length` options when using `Raxx.Server` so protect against bad clients.
- `Raxx.set_content_length/3` to set the content length of a request or response.
- `Raxx.get_content_length/2` to get the integer value for the content length of a message.
- `Raxx.set_attachment/2` helper to tell the browser the response should be stored on disk rather than displayed in the browser.
- `Raxx.safe?/1` to check if request method marks it as safe.
- `Raxx.idempotent?/1` to check if request method marks it as idempotent.
- `Raxx.get_query/1` replacement for `Raxx.fetch_query/1` because it never returns error case.

### Changed

- `Raxx.set_body/2` will raise an exception for responses that cannot have a body.
- `Raxx.set_body/2` automatically adds the "content-length" if it is able.
- Requests and Responses now work with iodata.
  - `Raxx.body` spec changed to include iodata.
  - Improved error message when using invalid iolist in a view.
  - `Raxx.NotFound` works with iodata for temporary body during buffering.
  - `render` function generated by `Raxx.View` sets body to iodata from view,
    without turning into a binary.
- `Raxx.set_header/2` now raises when setting connection specific headers.

### Removed

- `EEx.HTML` replaced by `EExHTML` from the `eex_html` hex package.
- `Raxx.html_escape/1` replaced by `EExHTML.escape_to_binary/1`.

### Fixed

- `Raxx.HTTP1.parse_request/1` and `Raxx.HTTP1.parse_response/1` handle more error cases.
  - response/request sent when request/response expected.
  - multiple "host" headers in message.
  - invalid "content-length" header.
  - multiple "content-length" headers in message.
  - invalid "connection" header.
  - multiple "connection" headers in message.

## [0.15.11](https://github.com/CrowdHailer/raxx/tree/0.15.11) - 2018-09-04

### Added
- `Raxx.View.javascript_variables/1` to safely inject values into the JavaScript of a template.

## [0.15.10](https://github.com/CrowdHailer/raxx/tree/0.15.10) - 2018-09-03

### Fixed

- `Raxx.HTTP1` to handle case insensitive connect headers.

## [0.15.9](https://github.com/CrowdHailer/raxx/tree/0.15.9) - 2018-09-02

### Added

- `Raxx.View` to generate render functions from `eex` templates.
- `Raxx.Layout` generate views from a reusable layout and set of helpers.
- `EEx.HTML`, `EEx.HTML.Safe` and `EEx.HTMLEngine`.
  **These are temporary additions**, used to provide HTML escaping in view and layout modules.
  They will be moved to `eex` or a new project before `1.0`.

## [0.15.8](https://github.com/CrowdHailer/raxx/tree/0.15.8) - 2018-08-27

### Added

- `Raxx.SimpleClient` A very simple HTTP/1.1 client.

## [0.15.7](https://github.com/CrowdHailer/raxx/tree/0.15.7) - 2018-08-18

### Added

- `Raxx.HTTP1` Tools for parsing and serializing to HTTP1 format.

## [0.15.6](https://github.com/CrowdHailer/raxx/tree/0.15.6) - 2018-08-09

### Fixed

- `Raxx.request` sets the raw_path as `/` when no path component given.

## [0.15.5](https://github.com/CrowdHailer/raxx/tree/0.15.5) - 2018-08-04

### Added

- `Raxx.request_host` to get the domain or ip a request is for.
- `Raxx.request_port` to get the numeric port a request is sent to.

## [0.15.4](https://github.com/CrowdHailer/raxx/tree/0.15.4) - 2018-05-20

### Added

- `:raxx` module added that is easier to use from erlang.

## [0.15.3](https://github.com/CrowdHailer/raxx/tree/0.15.3) - 2018-04-30

### Fixed

- Router will return informative return error like any server module.

## [0.15.2](https://github.com/CrowdHailer/raxx/tree/0.15.2) - 2018-04-28

### Added

- `Raxx.Server.handle/2` to be used by server implemenations when executing a `Raxx.Server` module.
  Add better error messages in cases of bad responses.

### Changed

- The type of `Raxx.body` and `Raxx.Data.data` is now `binary` instead of `String.t()` to indicate it may not be
  an actual string.
- Generate request_id without using external `uuid` dependency.

## [0.15.1](https://github.com/CrowdHailer/raxx/tree/0.15.1) - 2018-04-22

### Added

- `Raxx.Request` struct now has a `raw_path` field to hold the unparsed path of the URL.


## [0.15.0](https://github.com/CrowdHailer/raxx/tree/0.15.0) - 2018-04-18

### Added

- `Raxx.fetch_query/1` fetch the decoded query from a request.

### Changed

- The query field on the `Raxx.Request` struct is now a binary and not a parsed query.
  This is changed because there is no formal specification for query string structure.
  https://stackoverflow.com/questions/24059773/correct-way-to-pass-multiple-values-for-same-parameter-name-in-get-request

### Removed

- `URI2` is no longer part of this project, user will need to provide their own implementations to decode nested queries.

## [0.14.14](https://github.com/CrowdHailer/raxx/tree/0.14.14) - 2018-03-21

### Added

- `Raxx.set_secure_browser_headers/1` Adds a collection of useful headers when responding to a browser.
- `Raxx.delete_header/2` delete a header from request or response.
- `Raxx.RequestID` assign a request id to every request handled by an application

## [0.14.13](https://github.com/CrowdHailer/raxx/tree/0.14.13) - 2018-03-19

### Added

- Secure sessions in signed cookies by using `Raxx.Session.SignedCookie`.
- `Raxx.BasicAuth` for setting and verifying credentials using the Basic authentication scheme.

## [0.14.12](https://github.com/CrowdHailer/raxx/tree/0.14.12) - 2018-03-14

### Added

- `Raxx.get_header/2` for fetching a single header value from a request/response.
- `Raxx.redirect/2` will generate a redirect response directing browser to another url.
- Header values checked for forbidden charachters using `Raxx.set_header/3`.
- `Raxx.get_header/3` return fallback value if required header is not set.

## [0.14.11](https://github.com/CrowdHailer/raxx/tree/0.14.11) - 2018-03-08

### Added

- The source code is now formatted,
  ensuring code is properly formatted is part of CI and a requirement for contributions.

## [0.14.10](https://github.com/CrowdHailer/raxx/tree/0.14.10) - 2018-02-24

### Fixed

- Default page in `Raxx.Server` returned with status 404.

## [0.14.9](https://github.com/CrowdHailer/raxx/tree/0.14.9) - 2018-02-07

### Added

- `Raxx.Logger` sets request metadata on the logger.

## [0.14.8](https://github.com/CrowdHailer/raxx/tree/0.14.8) - 2018-02-05

### Added

- `:extra_statuses` configuration option added.

### Fixed

- `Raxx.Logger` uses `@impl` for all `Raxx.Server` callbacks.

## [0.14.7](https://github.com/CrowdHailer/raxx/tree/0.14.7) - 2018-01-30

### Added

- `Raxx.Logger` middleware for basic request logging.

## [0.14.6](https://github.com/CrowdHailer/raxx/tree/0.14.6) - 2018-01-03

### Fixed

- Typespec for `Raxx.set_body/2` reuses body type to fix issue with a binary not being a subtype of `iolist`.

## [1.0.0-rc.2](https://github.com/CrowdHailer/raxx/tree/1.0.0-rc.2)([0.14.5](https://github.com/CrowdHailer/raxx/tree/0.14.5)) - 2017-12-29

### Added

- Types `headers` and `body` added to `Raxx` module.

### Fixed

- Typespecs for `Raxx.response/1` accepts atom identifiers for status codes.
- Typespecs for `Raxx.set_body/2` and `Raxx.set_header/3` fixed to accept both Raxx message types.

## [0.14.4](https://github.com/CrowdHailer/raxx/tree/0.14.4) - 2017-12-28

### Added

- `Raxx.is_application?/1` Test to see if an application is compatable to run on Raxx Servers.
- `Raxx.verify_application/1` Same test as `is_application?/1` but returns informativ error.
- Typespecs for `Raxx.split_path/1` and `Raxx.set_body/2`

## [0.14.3](https://github.com/CrowdHailer/raxx/tree/0.14.3) - 2017-12-12

### Added
- Typespecs for all public functions.
- Dialyzer step added to CI.

## [0.14.2](https://github.com/CrowdHailer/raxx/tree/0.14.2) - 2017-11-14

### Fixed

- Correctly split file on new lines when generating status code helpers.

## [0.14.1](https://github.com/CrowdHailer/raxx/tree/0.14.1) - 2017-11-05

### Added

- `Raxx.reason_phrase/1` Get the HTTP/1 reason phrase for each status code.

### Removed

- Dependency on http_status no longer necessary.

## [1.0.0-rc.1](https://github.com/CrowdHailer/raxx/tree/1.0.0-rc.1)([0.14.0](https://github.com/CrowdHailer/raxx/tree/0.14.0)) - 2017-10-29

### Changed

- `handle_headers` has been renamed to `handle_head`.
  *As previously decribed in README.*

### Fixed

- Informative error raised for returning incomplete response without new state

## [1.0.0-rc.0](https://github.com/CrowdHailer/raxx/tree/1.0.0-rc.0)([0.13.0](https://github.com/CrowdHailer/raxx/tree/0.13.0)) - 2017-10-16

### Changed

- `Raxx.Trailer` has been renamed to `Raxx.Tail`.
- `handle_trailers` has been renamed to `handle_tail`.
- `Raxx.Fragment` has been replaced by `Raxx.Data`.
- `handle_fragment` has been replaced by `handle_data`

### Removed
- Specific header modules that were prevously deprecated.
  - `Raxx.Connection`
  - `Raxx.ContentLength`
  - `Raxx.Location`
  - `Raxx.Referrer`
  - `Raxx.TransferEncoding`
  - `Raxx.UserAgent`

## [0.12.3](https://github.com/CrowdHailer/raxx/tree/0.12.3) - 2017-10-14

### Added
- Using `Raxx.Server` imports helper functions from `Raxx`.
- Using `Raxx.Server` aliases `Raxx.Request`.
- Using `Raxx.Server` aliases `Raxx.Response`.

### Removed
- Dependency on `Plug` is not needed.
- Support for Elixir 1.4, `Raxx.Router` had bugs.

## [0.12.2](https://github.com/CrowdHailer/raxx/tree/0.12.2) - 2017-10-11

### Added

- `Raxx.trailer/0` completes request without any extra metadata.
- `handle_request/2` added to `Raxx.Server` behaviour.
- Default implementations added to `Raxx.Server` callbacks.
- `Raxx.Router` will forward request to controllers based on request patterns.

## [0.12.1](https://github.com/CrowdHailer/raxx/tree/0.12.1) - 2017-09-24

### Fixed
- Cannot set HTTP headers with uppercase attribute.
- Cannot add an HTTP header twice.

## [0.12.0](https://github.com/CrowdHailer/raxx/tree/0.12.0) - 2017-08-31

### Changed
- Replace simple interface with a streaming interface through `Raxx.Server`.
  See full [article](https://hexdocs.pm/tokumei/interface-design-for-http-streaming.html#content).
- Build messages with `Raxx` module instead or `Raxx.Request` and `Raxx.Response`.
