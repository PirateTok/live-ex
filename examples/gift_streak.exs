#!/usr/bin/env elixir
# Gift streak tracker — shows per-event deltas for combo gifts.
# Usage: mix run examples/gift_streak.exs <username>

alias PirateTok.Live.Helpers.GiftStreakTracker

[username | _] = System.argv()

IO.puts("Connecting to @#{username}...")

{:ok, _pid} = PirateTok.Live.connect(username)

defmodule StreakLoop do
  alias PirateTok.Live.Helpers.GiftStreakTracker

  def run(tracker \\ GiftStreakTracker.new(), total_diamonds \\ 0) do
    receive do
      {:tiktok_live, :connected, %{room_id: room_id}} ->
        IO.puts("Connected to room #{room_id}! Tracking gift streaks...\n")
        run(tracker, total_diamonds)

      {:tiktok_live, :gift, msg} ->
        {enriched, tracker} = GiftStreakTracker.process(tracker, msg)

        nick = if msg.user, do: msg.user.nickname, else: "?"
        name = if msg.gift_details, do: msg.gift_details.name, else: "?"

        if enriched.is_final do
          new_total = total_diamonds + enriched.total_diamond_count

          IO.puts(
            "[FINAL] streak=#{enriched.streak_id} #{nick} -> #{name}" <>
              " x#{enriched.total_gift_count} — #{enriched.total_diamond_count} diamonds"
          )

          IO.puts("        running total: #{new_total} diamonds\n")
          run(tracker, new_total)
        else
          if enriched.event_gift_count > 0 do
            IO.puts(
              "[ongoing] streak=#{enriched.streak_id} #{nick} -> #{name}" <>
                " +#{enriched.event_gift_count} (+#{enriched.event_diamond_count} dmnd)"
            )
          end

          run(tracker, total_diamonds)
        end

      {:tiktok_live, :live_ended, _} ->
        IO.puts("\n[stream ended] Total diamonds: #{total_diamonds}")
        IO.puts("Active streaks at end: #{GiftStreakTracker.active_streaks(tracker)}")

      {:tiktok_live, :disconnected, _} ->
        IO.puts("\nDisconnected. Total diamonds: #{total_diamonds}")
        IO.puts("Active streaks at disconnect: #{GiftStreakTracker.active_streaks(tracker)}")

      {:tiktok_live, _type, _data} ->
        run(tracker, total_diamonds)
    end
  end
end

StreakLoop.run()
