defmodule Raxx.Cookie.Attributes do
  defstruct domain: nil, path: nil, secure: false, http_only: false

  def to_header_string(attributes) do
    [
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

  def domain_av(nil), do: ""
  def domain_av(domain), do: "Domain=#{domain}"

  def path_av(nil), do: ""
  def path_av(path), do: "Path=#{path}"

  def secure_av(false), do: ""
  def secure_av(true), do: "Secure"

  def httponly_av(false), do: ""
  def httponly_av(true), do: "HttpOnly"
end
defmodule Raxx.Cookie do
  defstruct name: "", value: "", attributes: %Raxx.Cookie.Attributes{}
  def new(name, value, opts \\ %{}) do
    %__MODULE__{name: name, value: value, attributes: struct(Raxx.Cookie.Attributes, opts)}
  end

  # set-cookie-header = "Set-Cookie:" SP set-cookie-string
  def set_cookie_header(set_cookie_string) do
    "Set-Cookie: " <> set_cookie_string
  end

  def set_cookie_string(%{name: name, value: value, attributes: attributes}) do
    cookie_pair(name, value) <> Raxx.Cookie.Attributes.to_header_string(attributes)
  end

  def cookie_pair(name, value) do
    "#{name}=#{value}"
  end
end
