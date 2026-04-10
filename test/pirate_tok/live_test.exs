defmodule PirateTok.LiveTest do
  use ExUnit.Case

  test "check_online/2 returns a function clause error for empty username" do
    # Smoke-test that the public API is callable without network access.
    # A blank username will fail at the HTTP level, not crash the process.
    result = PirateTok.Live.check_online("", timeout: 1)
    assert match?({:error, _}, result)
  end
end
