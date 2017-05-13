defmodule SetCookie do
  @doc """
  Parse a `set-cookie` header, into key, value and attributes.

  ## Examples

      # Will parse cookie content
      iex> parse("foo=bar; path=/; HttpOnly")
      ...> |> Map.take([:key, :value])
      %{key: "foo", value: "bar"}

      # Will parse cookie attributes
      iex> parse("foo=bar; path=/; HttpOnly")
      ...> |> Map.get(:attributes)
      %{http_only: true, path: "/"}

      # Will parse cookie with empty value
      iex> parse("foo=; path=/; HttpOnly")
      ...> |> Map.take([:key, :value])
      %{key: "foo", value: ""}

      # Will parse domain attribute
      iex> parse("foo=bar; domain=example.com")
      ...> |> Map.get(:attributes)
      %{domain: "example.com"}

      # Will parse secure attribute
      iex> parse("foo=bar; secure")
      ...> |> Map.get(:attributes)
      %{secure: true}

      # Will parse max_age attribute
      iex> parse("foo=bar; max-age=20")
      ...> |> Map.get(:attributes)
      %{max_age: "20"}

      # Will parse expires attribute
      iex> parse("foo=bar; expires=Thu, 01 Jan 1970 00:00:00 GMT")
      ...> |> Map.get(:attributes)
      %{expires: "Thu, 01 Jan 1970 00:00:00 GMT"}

  """
  def parse(set_cookie_string) do
    [content | attributes] = String.split(set_cookie_string, ~r/;\s*/)
    [key, value] = String.split(content, "=", parts: 2)
    attributes = Enum.map(attributes, &parse_attribute/1) |> Enum.into(%{})
    %{key: key, value: value, attributes: attributes}
  end

  defp parse_attribute("domain=" <> domain), do: {:domain, domain}
  defp parse_attribute("path=" <> path), do: {:path, path}
  defp parse_attribute("HttpOnly"), do: {:http_only, true}
  defp parse_attribute("secure"), do: {:secure, true}
  defp parse_attribute("max-age=" <> max_age), do: {:max_age, max_age}
  defp parse_attribute("expires=" <> expires), do: {:expires, expires}
  defp parse_attribute(extra), do: {:extra, extra}

  @epoch {{1970, 1, 1}, {0, 0, 0}}

  @doc """
  Serialize a `set-cookie` header to expire the cookie.

  Options are the same as `serialize/3` minus `:max_age` and `:expires`.

  ## Examples

      # Expire a cookie value
      iex> expire("foo")
      "foo=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT; max-age=0; HttpOnly"

      # Expire a cookie with routing options
      iex> expire("foo", secure: true, http_only: false)
      "foo=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT; max-age=0; secure"

  """
  def expire(key, opts \\ []) do
    opts = Enum.into(opts, %{})
    opts = Map.merge(opts, %{max_age: 0, universal_time: @epoch})

    serialize(key, "", opts)
  end

  @doc """
  Serialize a cookie with options to format for `set-cookie` header.

  The cookie value is not automatically escaped. Therefore, if you
  want to store values with comma, quotes, etc, you need to explicitly
  escape them or use a function such as `Base.encode64` when writing
  and `Base.decode64` when reading the cookie.

  ## Options

  * `:domain` - the domain the cookie applies to
  * `:max_age` - the cookie max-age, in seconds. Providing a value for this
    option will set both the _max-age_ and _expires_ cookie attributes
  * `:path` - the path the cookie applies to
  * `:http_only` - when false, the cookie is accessible beyond http
  * `:secure` - if the cookie must be sent only over https. Defaults
    to true when the connection is https
  * `:extra` - string to append to cookie. Use this to take advantage of
    non-standard cookie attributes.

  ## Examples

      # Encode cookie with default options
      iex> serialize("foo", "bar")
      "foo=bar; path=/; HttpOnly"

      # Encode cookie with empty value
      iex> serialize("foo", "")
      "foo=; path=/; HttpOnly"

      # encodes with :path option
      iex> serialize("foo", "bar", path: "/baz")
      "foo=bar; path=/baz; HttpOnly"

      # encodes with :domain option
      iex> serialize("foo", "bar", domain: "example.com")
      "foo=bar; path=/; domain=example.com; HttpOnly"

      # encodes with :secure option
      iex> serialize("foo", "bar", secure: true)
      "foo=bar; path=/; secure; HttpOnly"

      # encodes with :http_only option, which defaults to true
      iex> serialize("foo", "bar", http_only: false)
      "foo=bar; path=/"

      # encodes with :max_age
      iex> start  = {{2012, 9, 29}, {15, 32, 10}}
      ...> serialize("foo", "bar", %{max_age: 60, universal_time: start})
      "foo=bar; path=/; expires=Sat, 29 Sep 2012 15:33:10 GMT; max-age=60; HttpOnly"

      # encodes whith :extra option
      iex> serialize("foo", "bar", extra: "SameSite=Lax")
      "foo=bar; path=/; HttpOnly; SameSite=Lax"

  """
  def serialize(key, value, opts \\ []) do
    opts = Enum.into(opts, %{})

    path   = Map.get(opts, :path, "/")

    "#{key}=#{value}; path=#{path}"
    |> concat_if(opts[:domain], &"; domain=#{&1}")
    |> concat_if(opts[:max_age], &encode_max_age(&1, opts))
    |> concat_if(Map.get(opts, :secure, false), "; secure")
    |> concat_if(Map.get(opts, :http_only, true), "; HttpOnly")
    |> concat_if(opts[:extra], &"; #{&1}")
  end

  defp encode_max_age(max_age, opts) do
    time = Map.get(opts, :universal_time) || :calendar.universal_time
    time = add_seconds(time, max_age)
    "; expires=" <> rfc2822(time) <> "; max-age=" <> Integer.to_string(max_age)
  end

  defp concat_if(acc, value, fun_or_string) do
    cond do
      !value ->
        acc
      is_function(fun_or_string) ->
        acc <> fun_or_string.(value)
      is_binary(fun_or_string) ->
        acc <> fun_or_string
    end
  end

  defp pad(number) when number in 0..9, do: <<?0, ?0 + number>>
  defp pad(number), do: Integer.to_string(number)

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

  defp add_seconds(time, seconds_to_add) do
    time_seconds = :calendar.datetime_to_gregorian_seconds(time)
    :calendar.gregorian_seconds_to_datetime(time_seconds + seconds_to_add)
  end
end
