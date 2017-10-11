# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## master

## Added

- `Raxx.trailer/0` completes request without any extra metadata.
- `handle_request/2` added to `Raxx.Server` behaviour.
- Default implementations added to `Raxx.Server` callbacks.

## [0.12.1](https://github.com/CrowdHailer/raxx/tree/0.12.1) - 2017-09-24

## Fixed
- Cannot set HTTP headers with uppercase attribute.
- Cannot add an HTTP header twice.

## [0.12.0](https://github.com/CrowdHailer/raxx/tree/0.12.0) - 2017-08-31

## Changed
- Replace simple interface with a streaming interface through `Raxx.Server`.
  See full [article](https://hexdocs.pm/tokumei/interface-design-for-http-streaming.html#content).
- Build messages with `Raxx` module instead or `Raxx.Request` and `Raxx.Response`.
