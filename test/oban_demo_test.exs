defmodule ObanDemoTest do
  use ExUnit.Case
  doctest ObanDemo

  test "greets the world" do
    assert ObanDemo.hello() == :world
  end
end
