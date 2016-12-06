defmodule Raxx.Upload do
  # just need three parameters for upload
  # http://www.wooptoot.com/file-upload-with-sinatra
  # %Raxx.Upload{
  #   filename: "cat.png",
  #   type: "image/png",
  #   contents: "some text"
  # }
  # https://tools.ietf.org/html/rfc7578#section-4.1
  defstruct [:filename, :type, :content]
end
