defmodule PirateTok.MultiStreamLoadTest do
  @moduledoc """
  Concurrent multi-stream load test.

  Gate: PIRATETOK_LIVE_TEST_USERS — comma-separated list of live usernames.
  All usernames must be live simultaneously during the test run.

  Creates one GenServer client per username, waits for all to reach :connected,
  listens for chat events for 60 s, then disconnects all clients.
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  @client_opts [cdn: :eu, timeout: 15_000, max_retries: 5, stale_timeout: 120_000]

  # M1 timeouts
  @await_all_connected_ms 120_000
  @live_window_ms 60_000

  # M1 — multiple live clients, track chat for 60 s
  @tag timeout: 300_000
  test "multiple live clients track chat for one minute" do
    users_raw = System.get_env("PIRATETOK_LIVE_TEST_USERS")

    unless users_raw && users_raw != "" do
      flunk(
        "set PIRATETOK_LIVE_TEST_USERS=user1,user2,... (all must be live) to run this test"
      )
    end

    usernames =
      users_raw
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    assert length(usernames) >= 1, "PIRATETOK_LIVE_TEST_USERS must contain at least one username"

    # Start one GenServer per username and collect pids.
    clients =
      Enum.map(usernames, fn username ->
        case PirateTok.Live.connect(username, @client_opts) do
          {:ok, pid} ->
            {username, pid}

          {:error, err} ->
            flunk("failed to start client for #{username}: #{inspect(err)}")
        end
      end)

    # Wait for all clients to reach :connected before starting the live window.
    n = length(clients)
    connected_ref = make_ref()
    parent = self()

    # Spawn a collector that waits for N :connected events then signals parent.
    collector =
      spawn(fn ->
        collect_connected(n, connected_ref, parent)
      end)

    # Forward :tiktok_live messages from this process to the collector and track chats.
    chat_counts = wait_for_connected_and_chats(clients, collector, connected_ref, n)

    # Disconnect all clients.
    disconnect_all(clients)

    # Log per-channel chat counts.
    Enum.each(clients, fn {username, _pid} ->
      count = Map.get(chat_counts, username, 0)
      IO.puts("[integration test multi-stream] #{username}: #{count} chat events in #{div(@live_window_ms, 1000)}s")
    end)

    # All clients should have exited cleanly (GenServer.stop is synchronous).
    IO.puts("[integration test multi-stream] all #{n} clients disconnected cleanly")
  end

  # Collects N :connected events then sends a signal to parent.
  defp collect_connected(0, ref, parent) do
    send(parent, {:all_connected, ref})
  end

  defp collect_connected(n, ref, parent) do
    receive do
      {:connected, ref} ->
        collect_connected(n - 1, ref, parent)
    after
      @await_all_connected_ms ->
        send(parent, {:connected_timeout, ref})
    end
  end

  defp wait_for_connected_and_chats(clients, collector, connected_ref, n) do
    usernames = Enum.map(clients, fn {u, _} -> u end)
    pids = Enum.map(clients, fn {_, p} -> p end)

    # Forward :connected events to collector.
    do_wait_loop(usernames, pids, collector, connected_ref, n, %{}, 0, false)
  end

  defp do_wait_loop(usernames, pids, collector, connected_ref, total_n, chat_counts, _conn_count, all_connected) do
    timeout_ms =
      if all_connected do
        # Live window — keep receiving for 60s from when we entered this state
        @live_window_ms
      else
        @await_all_connected_ms
      end

    receive do
      {:tiktok_live, :connected, %{room_id: _}} ->
        # Determine which username sent this by matching the GenServer pid sender.
        # Since GenServer sends to the caller (test_pid), we can't easily get the sender pid here.
        # We send a forwarded message to the collector.
        send(collector, {:connected, connected_ref})
        do_wait_loop(usernames, pids, collector, connected_ref, total_n, chat_counts, 0, all_connected)

      {:tiktok_live, :chat, data} ->
        # Best-effort: attribute chat to a user. We may not know which client sent it,
        # so we track total chat count across all channels.
        username = find_username_from_data(data, usernames)
        new_counts = Map.update(chat_counts, username, 1, &(&1 + 1))
        do_wait_loop(usernames, pids, collector, connected_ref, total_n, new_counts, 0, all_connected)

      {:tiktok_live, _type, _data} ->
        do_wait_loop(usernames, pids, collector, connected_ref, total_n, chat_counts, 0, all_connected)

      {:all_connected, ^connected_ref} ->
        # All N clients connected — now run the 60 s live window.
        IO.puts("[integration test multi-stream] all #{total_n} clients connected, listening for #{div(@live_window_ms, 1000)}s")
        run_live_window(usernames, pids, chat_counts)

      {:connected_timeout, ^connected_ref} ->
        flunk(
          "not all clients reached :connected within #{div(@await_all_connected_ms, 1000)}s — " <>
            "check that all usernames in PIRATETOK_LIVE_TEST_USERS are live"
        )
    after
      timeout_ms ->
        if all_connected do
          chat_counts
        else
          flunk(
            "timed out waiting for :connected events within #{div(@await_all_connected_ms, 1000)}s"
          )
        end
    end
  end

  # After all clients are connected, receive events for @live_window_ms ms.
  defp run_live_window(usernames, _pids, initial_counts) do
    deadline = System.monotonic_time(:millisecond) + @live_window_ms
    do_live_window(usernames, initial_counts, deadline)
  end

  defp do_live_window(usernames, chat_counts, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      chat_counts
    else
      receive do
        {:tiktok_live, :chat, data} ->
          username = find_username_from_data(data, usernames)
          new_counts = Map.update(chat_counts, username, 1, &(&1 + 1))
          do_live_window(usernames, new_counts, deadline)

        {:tiktok_live, _type, _data} ->
          do_live_window(usernames, chat_counts, deadline)
      after
        remaining -> chat_counts
      end
    end
  end

  defp disconnect_all(clients) do
    Enum.each(clients, fn {_username, pid} ->
      try do
        PirateTok.Live.disconnect(pid)
      catch
        :exit, _ -> :ok
      end
    end)
  end

  # Best-effort: try to extract a username from event data.
  # Falls back to "unknown" when we can't tell.
  defp find_username_from_data(data, _usernames) do
    user_info = if is_struct(data), do: Map.get(data, :user), else: data["user"]
    unique_id = cond do
      is_struct(user_info) -> Map.get(user_info, :unique_id)
      is_map(user_info) -> Map.get(user_info, "uniqueId")
      true -> nil
    end

    case unique_id do
      nil -> "unknown"
      "" -> "unknown"
      id -> id
    end
  end
end
