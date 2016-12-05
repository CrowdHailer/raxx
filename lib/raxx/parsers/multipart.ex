defmodule Raxx.Parsers.Multipart do
  def parse(request) do
    case Raxx.Request.content_type(request) do
      {"multipart/form-data", "boundary=" <> boundary} ->
        decode(request.body, boundary)
    end
  end

  def decode(data, boundary) do
    ["" | parts] = String.split(data, "--" <> boundary)
    Enum.reduce(parts, [], fn
      ("--\r\n", data) ->
        data
      ("\r\n" <> part, data) ->
        {:ok, headers, body} = read_multipart_headers(part)
        "form-data;" <> params = :proplists.get_value("content-disposition", headers)
        [body, ""] = String.split(body, ~r"\r\n$")
        params = String.strip(params)
        params = Raxx.Cookie.parse([params])
        name = String.slice(Map.get(params, "name"), 1..-2)
        case Map.get(params, "filename") do
          nil ->
            data ++ [{name, body}]
          filename ->
            filename = String.slice(filename, 1..-2)
            data ++ [{name, %Raxx.Request.Upload{
              filename: filename,
              type: :proplists.get_value("content-type", headers),
              content: body
              }}]

        end
    end)
    |> Enum.into(%{})
  end

  def read_multipart_headers(part, headers \\ []) do
    case :erlang.decode_packet(:httph_bin, part, []) do
      {:ok, {:http_header, _, key, _, value}, rest} ->
        headers = [{String.downcase("#{key}"), value} | headers]
        {:ok, headers, body} = read_multipart_headers(rest, headers)
      {:ok, :http_eoh, rest} ->
        {:ok, Enum.reverse(headers), rest}
    end
  end
end
