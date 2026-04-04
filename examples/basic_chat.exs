#!/usr/bin/env elixir
# Connect to a TikTok Live stream and print events.
# Usage: mix run examples/basic_chat.exs <username>

[username | _] = System.argv()

IO.puts("Connecting to @#{username}...")

{:ok, _pid} = PirateTok.Live.connect(username)

defmodule ChatLoop do
  def run do
    receive do
      {:tiktok_live, :connected, %{room_id: room_id}} ->
        IO.puts("Connected to room #{room_id}! Waiting for events...\n")
        run()

      {:tiktok_live, :chat, msg} ->
        nick = if msg.user, do: msg.user.nickname, else: "?"
        IO.puts("#{nick}: #{msg.comment}")
        run()

      {:tiktok_live, :gift, msg} ->
        nick = if msg.user, do: msg.user.nickname, else: "?"
        name = if msg.gift_details, do: msg.gift_details.name, else: "?"
        IO.puts("[gift] #{nick} sent #{name} x#{max(msg.repeat_count, 1)}")
        run()

      {:tiktok_live, :like, msg} ->
        nick = if msg.user, do: msg.user.nickname, else: "?"
        IO.puts("[like] #{nick} (#{msg.total_like_count} total)")
        run()

      {:tiktok_live, :join, msg} ->
        IO.puts("[join] member_count=#{msg.member_count}")
        run()

      {:tiktok_live, :room_user_seq, msg} ->
        IO.puts("[viewers] #{msg.total_user} total, pop=#{msg.popularity}")
        run()

      {:tiktok_live, :follow, msg} ->
        nick = if msg.user, do: msg.user.nickname, else: "?"
        IO.puts("[follow] #{nick}")
        run()

      {:tiktok_live, :live_ended, _msg} ->
        IO.puts("[stream ended]")

      {:tiktok_live, :reconnecting, info} ->
        IO.puts("[reconnecting] attempt #{info.attempt}/#{info.max_retries} in #{info.delay_secs}s")
        run()

      {:tiktok_live, :disconnected, _} ->
        IO.puts("Disconnected.")

      {:tiktok_live, :error, err} ->
        IO.puts("Error: #{err.message}")

      {:tiktok_live, _type, _data} ->
        run()
    end
  end
end

ChatLoop.run()
