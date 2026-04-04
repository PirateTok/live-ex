#!/usr/bin/env elixir
# Track gifts with running diamond total.
# Usage: mix run examples/gift_tracker.exs <username>

[username | _] = System.argv()

IO.puts("Connecting to @#{username}...")

{:ok, _pid} = PirateTok.Live.connect(username)

defmodule GiftLoop do
  def run(total \\ 0) do
    receive do
      {:tiktok_live, :connected, %{room_id: room_id}} ->
        IO.puts("Connected to room #{room_id}! Tracking gifts...\n")
        run(total)

      {:tiktok_live, :gift, msg} ->
        nick = if msg.user, do: msg.user.nickname, else: "?"
        name = if msg.gift_details, do: msg.gift_details.name, else: "?"
        diamonds = (msg.gift_details && msg.gift_details.diamond_count) || 0
        count = max(msg.repeat_count, 1)
        gift_diamonds = diamonds * count
        new_total = total + gift_diamonds

        if msg.repeat_end == 1 or msg.repeat_count <= 1 do
          IO.puts("[gift] #{nick} sent #{name} x#{count} — #{gift_diamonds} diamonds")
          IO.puts("       Running total: #{new_total} diamonds\n")
        end

        run(new_total)

      {:tiktok_live, :live_ended, _} ->
        IO.puts("\n[stream ended] Total diamonds: #{total}")

      {:tiktok_live, :disconnected, _} ->
        IO.puts("\nDisconnected. Total diamonds: #{total}")

      {:tiktok_live, _type, _data} ->
        run(total)
    end
  end
end

GiftLoop.run()
