defmodule PirateTok.WssSmokeTest do
  @moduledoc """
  WebSocket smoke tests against a real live room.

  Gate: PIRATETOK_LIVE_TEST_USER must be set to a username that is live during the run.
  Tests are inherently flaky on quiet streams — missing an event type is not a bug.

  All tests run on EU CDN with 15 s HTTP timeout, 5 retries, 45 s stale timeout.
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  @client_opts [cdn: :eu, timeout: 15_000, max_retries: 5, stale_timeout: 45_000]

  @await_traffic_ms 90_000
  @await_chat_ms 120_000
  @await_gift_ms 180_000
  @await_like_ms 120_000
  @await_join_ms 150_000
  @await_follow_ms 180_000
  @await_subscription_ms 240_000
  @await_connected_ms 90_000
  @disconnect_join_ms 18_000

  defp require_test_user do
    case System.get_env("PIRATETOK_LIVE_TEST_USER") do
      nil -> flunk("set PIRATETOK_LIVE_TEST_USER=<live_username> to run WSS smoke tests")
      "" -> flunk("set PIRATETOK_LIVE_TEST_USER=<live_username> to run WSS smoke tests")
      user -> String.trim(user)
    end
  end

  # Connect from THIS process so events arrive in our mailbox.
  # Returns the client pid. Caller must disconnect in an `after` block.
  defp connect_from_test(user) do
    case PirateTok.Live.connect(user, @client_opts) do
      {:ok, pid} -> pid
      {:error, err} -> flunk("connect failed: #{inspect(err)}")
    end
  end

  # Wait for any message matching one of the event atoms.
  defp wait_for_event(event_atoms, timeout_ms) when is_list(event_atoms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait(event_atoms, deadline)
  end

  defp do_wait(event_atoms, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    if remaining <= 0 do
      :timeout
    else
      receive do
        {:tiktok_live, type, data} ->
          if type in event_atoms do
            {:ok, type, data}
          else
            do_wait(event_atoms, deadline)
          end
      after
        remaining -> :timeout
      end
    end
  end

  # Wait for a single event type, log it, return :ok or :timeout.
  defp wait_for_event_with_log(event_atom, timeout_ms, log_fn) do
    case wait_for_event([event_atom], timeout_ms) do
      {:ok, _type, data} ->
        log_fn.(data)
        :ok

      :timeout ->
        :timeout
    end
  end

  defp get_nickname(data) do
    user = if is_struct(data), do: Map.get(data, :user), else: data["user"]
    cond do
      is_struct(user) -> Map.get(user, :nickname, "?")
      is_map(user) -> Map.get(user, "nickname", "?")
      true -> "?"
    end
  end

  # W1
  test "connect receives traffic before timeout" do
    user = require_test_user()
    pid = connect_from_test(user)

    try do
      case wait_for_event([:room_user_seq, :member, :chat, :like, :control, :connected], @await_traffic_ms) do
        {:ok, _, _} -> :ok
        :timeout -> flunk("no room traffic within #{div(@await_traffic_ms, 1000)}s (quiet stream or block)")
      end
    after
      PirateTok.Live.disconnect(pid)
    end
  end

  # W2
  test "connect receives chat before timeout" do
    user = require_test_user()
    pid = connect_from_test(user)

    try do
      case wait_for_event_with_log(:chat, @await_chat_ms, fn data ->
             nick = get_nickname(data)
             comment = if is_struct(data), do: Map.get(data, :comment, "?"), else: data["comment"] || "?"
             IO.puts("[integration test chat] #{nick}: #{comment}")
           end) do
        :ok -> :ok
        :timeout -> flunk("no chat within #{div(@await_chat_ms, 1000)}s (quiet stream or block)")
      end
    after
      PirateTok.Live.disconnect(pid)
    end
  end

  # W3
  test "connect receives gift before timeout" do
    user = require_test_user()
    pid = connect_from_test(user)

    try do
      case wait_for_event_with_log(:gift, @await_gift_ms, fn data ->
             nick = get_nickname(data)
             gift_id = if is_struct(data), do: Map.get(data, :gift_id, "?"), else: data["gift_id"] || "?"
             repeat = if is_struct(data), do: Map.get(data, :repeat_count, 1), else: data["repeat_count"] || 1
             IO.puts("[integration test gift] #{nick} -> gift_id=#{gift_id} x#{repeat}")
           end) do
        :ok -> :ok
        :timeout -> flunk("no gift within #{div(@await_gift_ms, 1000)}s (try a busier stream)")
      end
    after
      PirateTok.Live.disconnect(pid)
    end
  end

  # W4
  test "connect receives like before timeout" do
    user = require_test_user()
    pid = connect_from_test(user)

    try do
      case wait_for_event_with_log(:like, @await_like_ms, fn data ->
             nick = get_nickname(data)
             count = if is_struct(data), do: Map.get(data, :like_count, "?"), else: data["like_count"] || "?"
             IO.puts("[integration test like] #{nick} count=#{count}")
           end) do
        :ok -> :ok
        :timeout -> flunk("no like within #{div(@await_like_ms, 1000)}s (quiet stream or block)")
      end
    after
      PirateTok.Live.disconnect(pid)
    end
  end

  # W5
  test "connect receives join before timeout" do
    user = require_test_user()
    pid = connect_from_test(user)

    try do
      case wait_for_event_with_log(:join, @await_join_ms, fn data ->
             nick = get_nickname(data)
             IO.puts("[integration test join] #{nick}")
           end) do
        :ok -> :ok
        :timeout -> flunk("no join within #{div(@await_join_ms, 1000)}s (try a busier stream)")
      end
    after
      PirateTok.Live.disconnect(pid)
    end
  end

  # W6
  test "connect receives follow before timeout" do
    user = require_test_user()
    pid = connect_from_test(user)

    try do
      case wait_for_event_with_log(:follow, @await_follow_ms, fn data ->
             nick = get_nickname(data)
             IO.puts("[integration test follow] #{nick}")
           end) do
        :ok -> :ok
        :timeout -> flunk("no follow within #{div(@await_follow_ms, 1000)}s (follows are infrequent)")
      end
    after
      PirateTok.Live.disconnect(pid)
    end
  end

  # W7 (disabled)
  @tag :skip
  test "connect receives subscription signal before timeout" do
    user = require_test_user()
    pid = connect_from_test(user)

    try do
      case wait_for_event([:sub_notify, :subscription_notify, :sub_capsule, :sub_pin_event], @await_subscription_ms) do
        {:ok, _, _} -> :ok
        :timeout -> flunk("no subscription event within #{div(@await_subscription_ms, 1000)}s")
      end
    after
      PirateTok.Live.disconnect(pid)
    end
  end

  # D1
  test "disconnect unblocks connect after connected" do
    user = require_test_user()
    pid = connect_from_test(user)

    # Wait for :connected event
    connected =
      receive do
        {:tiktok_live, :connected, _} -> true
      after
        @await_connected_ms -> false
      end

    unless connected do
      PirateTok.Live.disconnect(pid)
      flunk("never reached :connected within #{div(@await_connected_ms, 1000)}s")
    end

    t0 = System.monotonic_time(:millisecond)
    PirateTok.Live.disconnect(pid)
    elapsed = System.monotonic_time(:millisecond) - t0

    assert elapsed < @disconnect_join_ms,
           "disconnect should return promptly, took #{elapsed}ms"
  end
end
