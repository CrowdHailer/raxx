# Cookie

**HTTP state management with cookies.**

- Download from [hex.pm](https://hex.pm/packages/cookie)
- Documentation available on [hexdocs.pm](https://hexdocs.pm/cookie/).

## Usage

See documentation for `Cookie` and `SetCookie`.

## Extra
For a good introduction to cookies check [http cookies explained](https://www.nczonline.net/blog/2009/05/05/http-cookies-explained/)

There are a lot of issues when it comes to formatting cookies.
The Wiki article for cookies discusses 3 relevant [RFC's](https://en.wikipedia.org/wiki/HTTP_cookie#History).
- RFC 2109 (Feb 1997) as the first specification for third-party cookies.
- RFC 2965 (Oct 2000) as a replacement to RFC 2109.
- RFC 6265 (Apr 2011) A definitive specification of real world usage.

The majority of this modules behaviour is directed by RCF 6265.
Where possible this extends to variable and method naming.

### Expires vs Max-Age

This two cookie attributes both exist for the same functionality.
i.e. giving a livetime to persisted cookies(if neither id given then the cookie is a session cookie).

There is more detail at [HTTP Cookies: What's the difference between Max-age and Expires?](http://mrcoles.com/blog/cookies-max-age-vs-expires/)
In summary max-age is the newer way to set cookie deletion.

Raxx does not convert from expires to max age or visa-versa.
Preferably use max-age for a simpler interface.
For old IE support use expires, new browsers still support this.
If you need both set then both will need to be set by the application.

The expires date format is the subject of conflicting RFC's the best is [RFC 2616](https://tools.ietf.org/html/rfc2616#section-3.3.1)
