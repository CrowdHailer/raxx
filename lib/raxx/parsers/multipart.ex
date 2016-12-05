defmodule Raxx.Parsers.Multipart do
  @moduledoc """
  This is all defined in the multipart/form-data [rfc7578](https://tools.ietf.org/html/rfc7578)

  - Add an `encode/1` function that can be used to create a body,
    mainly for testing purposes but also can be exposed as part of a 7578 hex package.
  - Consider separate parsing of data to named list [{"field-name[]", "data"}] and grouping to a map via "field-name[]"
  - this is an interesting library that might want to be emulated for nested queries. https://github.com/spiceworks/httpoison-form-data/blob/master/lib/form_data.ex
  - plug adapter test for failed decodings

  - Have uploads look as much like a file as possible
  http://ruby-doc.org/stdlib-1.9.3/libdoc/tempfile/rdoc/Tempfile.html#method-i-path
  - Read about erlang [io protocol](http://erlang.org/doc/apps/stdlib/io_protocol.html) to this end
  - Comparison listing the concerns of an image uploader
  https://infinum.co/the-capsized-eight/best-rails-image-uploader-paperclip-carrierwave-refile
  """
  # TODO add error case
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
