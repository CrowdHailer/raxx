# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## master

### Added

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
