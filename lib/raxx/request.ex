defmodule Raxx.Request do
  defstruct [
    host: "www.example.com",
    port: 80,
    method: "GET", # In ring/rack this is request_method
    path: [], # This is path_info but is often used so be good to shorten
    query: %{}, # comes from the search string
    headers: %{},
    body: ""
  ]

  def parse_cookies(%{headers: headers}) do
    case Map.get(headers, "cookie") do
      nil -> Raxx.Cookie.parse([])
      cookie_string -> Raxx.Cookie.parse(cookie_string)
    end
  end
end
