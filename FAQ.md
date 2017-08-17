# FAQ

### Where is 422 `unprocessable_entity`?

422 Unprocessable Entity was never part of the official spec, but it was used because the official definition of 400 Bad Request in [RFC 2616](https://tools.ietf.org/html/rfc2616#page-65) was too strict and only covered cases when the client sent a request with malformed syntax.

[RFC 7231](https://tools.ietf.org/html/rfc7231#section-6.5.1) expands the definition of 400 Bad Request to include anything perceived to be a client error, removing the need for a separate 422 response.

