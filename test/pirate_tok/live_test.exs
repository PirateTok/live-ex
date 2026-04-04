defmodule PirateTok.LiveTest do
  use ExUnit.Case
  doctest PirateTok.Live

  test "greets the world" do
    assert PirateTok.Live.hello() == :world
  end
end
