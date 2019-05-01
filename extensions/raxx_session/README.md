# Raxx.Session

**Manage HTTP cookies and storage for persistent client sessions.**

[![Hex pm](http://img.shields.io/hexpm/v/raxx_session.svg?style=flat)](https://hex.pm/packages/raxx_session)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

- [Install from hex.pm](https://hex.pm/packages/raxx_session)
- [Documentation available on hexdoc](https://hexdocs.pm/raxx_session)
- [Discuss on slack](https://elixir-lang.slack.com/messages/C56H3TBH8/)

## Usage

See `Raxx.Session` for usage and examples.

## Plug sessions

This library uses the `Plug.Crypto` module.
Sessions from Plug applications can be verified in Raxx applications, and visa versa,
if setup with the same configuration.
