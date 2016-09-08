defmodule Raxx.Cookie do
  # set-cookie-header = "Set-Cookie:" SP set-cookie-string
  def set_cookie_header(set_cookie_string) do
    "Set-Cookie: " <> set_cookie_string
  end

  # def set_cookie_string(name, value, attribute_value_pairs) do
  #   cookie_pair(name, value) <> attribute_value_pairs
  # end
  def set_cookie_string(name, value) do
    cookie_pair(name, value)
  end
  def set_cookie_string(name, value, options \\ %{}) do
    case Map.keys(options) do
      [] ->
        cookie_pair(name, value)
      _ ->
        cookie_pair(name, value) <> "; " <> (Enum.map(options, &cookie_av/1) |> Enum.join("; "))
    end
  end

  def cookie_av({:secure, true}) do
    "Secure"
  end
  def cookie_av({:http_only, true}) do
    "HttpOnly"
  end
  def cookie_av({:domain, domain}) do
    "Domain=#{domain}"
  end

  def cookie_pair(name, value) do
    "#{name}=#{value}"
  end
end
