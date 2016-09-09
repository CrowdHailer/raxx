defmodule Raxx.Cookie.Attributes do
  defstruct expires: nil,
  max_age: nil,
  domain: nil,
  path: nil,
  secure: false,
  http_only: false

  def to_header_string(attributes) do
    [
      expires_av(attributes.expires),
      max_age_av(attributes.max_age),
      domain_av(attributes.domain),
      path_av(attributes.path),
      secure_av(attributes.secure),
      httponly_av(attributes.http_only),
    ]
    |> Enum.map(fn
      ("") -> ""
      (s) -> "; #{s}"
    end)
    |> Enum.join("")
  end

  def expires_av(nil), do: ""
  def expires_av(expires), do: "Expires=#{sane_cookie_date(expires)}"

  def max_age_av(nil), do: ""
  def max_age_av(time_in_seconds_to_expiry), do: "Max-Age=#{time_in_seconds_to_expiry}"

  def domain_av(nil), do: ""
  def domain_av(domain), do: "Domain=#{domain}"

  def path_av(nil), do: ""
  def path_av(path), do: "Path=#{path}"

  def secure_av(false), do: ""
  def secure_av(true), do: "Secure"

  def httponly_av(false), do: ""
  def httponly_av(true), do: "HttpOnly"

  def sane_cookie_date(date) do
    rfc2822(date)
  end

  # Copied from Plug
  defp rfc2822({{year, month, day} = date, {hour, minute, second}}) do
    weekday_name  = weekday_name(:calendar.day_of_the_week(date))
    month_name    = month_name(month)
    padded_day    = pad(day)
    padded_hour   = pad(hour)
    padded_minute = pad(minute)
    padded_second = pad(second)
    binary_year   = Integer.to_string(year)

    weekday_name <> ", " <> padded_day <>
      " " <> month_name <> " " <> binary_year <>
      " " <> padded_hour <> ":" <> padded_minute <>
      ":" <> padded_second <> " GMT"
  end

  defp pad(number) when number in 0..9, do: <<?0, ?0 + number>>
  defp pad(number), do: Integer.to_string(number)

  defp weekday_name(1), do: "Mon"
  defp weekday_name(2), do: "Tue"
  defp weekday_name(3), do: "Wed"
  defp weekday_name(4), do: "Thu"
  defp weekday_name(5), do: "Fri"
  defp weekday_name(6), do: "Sat"
  defp weekday_name(7), do: "Sun"

  defp month_name(1),  do: "Jan"
  defp month_name(2),  do: "Feb"
  defp month_name(3),  do: "Mar"
  defp month_name(4),  do: "Apr"
  defp month_name(5),  do: "May"
  defp month_name(6),  do: "Jun"
  defp month_name(7),  do: "Jul"
  defp month_name(8),  do: "Aug"
  defp month_name(9),  do: "Sep"
  defp month_name(10), do: "Oct"
  defp month_name(11), do: "Nov"
  defp month_name(12), do: "Dec"
end
defmodule Raxx.Cookie do
  @moduledoc ~S"""
  For a good introduction to cookies check [http cookies explained](https://www.nczonline.net/blog/2009/05/05/http-cookies-explained/)

  There are a lot of issues when it comes to formatting cookies.
  The Wiki article for cookies discusses 3 relevant [RFC's](https://en.wikipedia.org/wiki/HTTP_cookie#History).
  - RFC 2109 (Feb 1997) as the first specification for third-party cookies.
  - RFC 2965 (Oct 2000) as a replacement to RFC 2109.
  - RFC 6265 (Apr 2011) A definitive specification of real world usage.

  The majority of this modules behaviour is directed by RCF 6265.
  Where possible this extends to variable and method naming.

  Additional sources are:
  - [the plug source code](https://github.com/elixir-lang/plug/blob/0b387966d2f21cf050ca666f328864b546b4e754/lib/plug/conn/cookies.ex)
  - [the rack source code](https://github.com/rack/rack/blob/95172a60fe5c2a3850163fc75e0981fe440c064e/lib/rack/utils.rb)

  Expires vs Max-Age
  This two cookie attributes both exist for the same functionality.
  i.e. giving a livetime to persisted cookies(if neither id given then the cookie is a session cookie).

  There is more detail at [HTTP Cookies: What's the difference between Max-age and Expires?](http://mrcoles.com/blog/cookies-max-age-vs-expires/)
  In summary max-age is the newer way to set cookie deletion.

  Raxx does not convert from expires to max age or visa-versa.
  Preferably use max-age for a simpler interface.
  For old IE support use expires, new browsers still support this.
  If you need both set then both will need to be set by the application.

  The expires date format is the subject of conflicting RFC's the best is [RFC 2616](https://tools.ietf.org/html/rfc2616#section-3.3.1)
  """
  
  defstruct name: "", value: "", attributes: %Raxx.Cookie.Attributes{}
  def new(name, value, opts \\ %{}) do
    %__MODULE__{name: name, value: value, attributes: struct(Raxx.Cookie.Attributes, opts)}
  end

  def set_cookie_string(%{name: name, value: value, attributes: attributes}) do
    cookie_pair(name, value) <> Raxx.Cookie.Attributes.to_header_string(attributes)
  end

  def cookie_pair(name, value) do
    "#{name}=#{value}"
  end

  def parse([]) do
    %{}
  end
  def parse([cookie_string]) do
    :binary.split(cookie_string, "; ")
    |> Enum.reject(fn(s) -> s == "" end)
    |> Enum.map(&parse_cookie_pair/1)
    |> Enum.into(%{})
  end

  def parse_cookie_pair(cookie_pair) do
    [name, value] = :binary.split(cookie_pair, "=")
    {name, value}
  end
end
