defmodule CowboyExample.Router do
  import Raxx.Response

  def call(_request, _opts) do
    ok("the page")
  end
end
