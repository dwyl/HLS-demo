defmodule HlsDemoTest do
  use ExUnit.Case
  doctest HlsDemo

  test "greets the world" do
    assert HlsDemo.hello() == :world
  end
end
