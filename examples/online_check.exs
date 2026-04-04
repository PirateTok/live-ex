#!/usr/bin/env elixir
# Check if a TikTok user is currently live.
# Usage: mix run examples/online_check.exs <username>

[username | _] = System.argv()

case PirateTok.Live.check_online(username) do
  {:ok, room_id} ->
    IO.puts("  LIVE  @#{username} — room #{room_id}")

  {:error, %{type: :host_not_online}} ->
    IO.puts("  OFF   @#{username} — not currently live")
    System.halt(1)

  {:error, %{type: :user_not_found}} ->
    IO.puts("  404   @#{username} — user does not exist")
    System.halt(1)

  {:error, err} ->
    IO.puts("  ERR   @#{username} — #{err.message}")
    System.halt(1)
end
