# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [0.2.5](#) - 2019-06-06

### Added

- Better checks for csrf protection.

## [0.2.4](#) - 2019-06-03

### Added

- new store `Raxx.Session.EncryptedCookie`, compatible with Plug sessions.

## [0.2.3](#) - 2019-05-09

### Added

- Expose `Raxx.Session.unprotected_extract/2`.

## [0.2.2](#) - 2019-05-09

### Fixed

- Empty session can be extracted from unsafe request without protection.
