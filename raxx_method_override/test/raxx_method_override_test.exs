defmodule Raxx.MethodOverrideTest do
  use ExUnit.Case

  alias Raxx.Request
  import Raxx.MethodOverride, only: [override_method: 1]

  test "override POST to PUT from form contents" do
    request = Request.put("/", %{body: %{"_method" => "PUT"}})
    |> override_method
    assert :PUT == request.method
  end

  test "override POST to PATCH from form contents" do
    request = %Request{method: :POST, body: %{"_method" => "PATCH"}}
    |> override_method
    assert :PATCH == request.method
  end

  test "override POST to DELETE from form contents" do
    request = %Request{method: :POST, body: %{"_method" => "DELETE"}}
    |> override_method
    assert :DELETE == request.method
  end

  test "overridding method removes the _method field from form" do
    request = %Request{method: :POST, body: %{"_method" => "PUT"}}
    |> override_method
    assert :error == Map.fetch(request.body, "_method")
  end

  test "override works with lowercase form contents" do
    request = %Request{method: :POST, body: %{"_method" => "delete"}}
    |> override_method
    assert :DELETE == request.method
  end

  test "does not allow unknown methods" do
    request = %Request{method: :POST, body: %{"_method" => "PARTY"}}
    |> override_method
    assert :POST == request.method
  end

  test "leaves non-POST requests unmodified, e.g. GET" do
    request = %Request{method: :GET, body: %{"_method" => "DELETE"}}
    |> override_method
    assert :GET == request.method
  end

  # Not entirely sure of the logic here.
  test "leaves non-POST requests unmodified, e.g. PUT" do
    request = %Request{method: :PUT, body: %{"_method" => "DELETE"}}
    |> override_method
    assert :PUT == request.method
  end

  test "unparsed bodies are not considered" do
    request = %Request{method: :POST, body: "_method=PATCH"}
    |> override_method
    assert :POST == request.method
  end

  test "forms with out a _method field are a no-op" do
    request = %Request{method: :POST, body: %{"other" => "PUT"}}
    |> override_method
    assert :POST == request.method
  end

end
