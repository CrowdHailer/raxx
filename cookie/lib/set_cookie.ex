defmodule SetCookie do
  def parse(cookie_string) do

  end

  @doc """
  Encode a cookie with options to format for `set-cookie` header.

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
