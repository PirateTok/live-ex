#!/usr/bin/env elixir
# Full audience roster of a live room. Login-gated: needs TikTok session cookies.
# Usage: mix run examples/audience.exs <username> "sessionid=xxx; sid_tt=xxx"

[username, cookies | _] = System.argv()

with {:ok, %{room_id: room_id, anchor_id: anchor_id}} <- PirateTok.Live.check_online(username),
     {:ok, aud} <- PirateTok.Live.fetch_room_audience(room_id, anchor_id, cookies: cookies) do
  IO.puts("total=#{aud.total} anonymous=#{aud.anonymous} named=#{length(aud.viewers)}")

  Enum.each(aud.viewers, fn v ->
    IO.puts("##{v.rank} #{v.username} (#{v.nickname}) score=#{v.score} followers=#{v.follower_count}")
  end)
else
  {:error, %{type: :session_required} = err} ->
    IO.puts("SESSION REQUIRED: #{err.message}")
    System.halt(4)

  {:error, err} ->
    IO.puts("ERR: #{err.message}")
    System.halt(1)
end
