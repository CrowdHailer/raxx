defmodule Raxx.MethodOverrideTest do
  use ExUnit.Case

  # DEBT make use of `Raxx.Test`
  test "override POST to PUT from form contents" do
    request = %Raxx.Request{method: :POST, body: %{"_method" => "PUT"}}
    |> Raxx.MethodOverride.override_method
    assert :PUT == request.method
  end

  test "override POST to PATCH from form contents" do
    request = %Raxx.Request{method: :POST, body: %{"_method" => "PATCH"}}
    |> Raxx.MethodOverride.override_method
    assert :PATCH == request.method
  end

  test "override POST to DELETE from form contents" do
    request = %Raxx.Request{method: :POST, body: %{"_method" => "DELETE"}}
    |> Raxx.MethodOverride.override_method
    assert :DELETE == request.method
  end

  test "override works with lowercase form contents" do
    request = %Raxx.Request{method: :POST, body: %{"_method" => "delete"}}
    |> Raxx.MethodOverride.override_method
    assert :DELETE == request.method
  end

  test "does not allow unknown methods" do
    request = %Raxx.Request{method: :POST, body: %{"_method" => "PARTY"}}
    |> Raxx.MethodOverride.override_method
    assert :POST == request.method
  end

end
