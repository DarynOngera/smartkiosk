defmodule SmartKioskCoreTest do
  use ExUnit.Case
  doctest SmartKioskCore

  test "greets the world" do
    assert SmartKioskCore.hello() == :world
  end
end
