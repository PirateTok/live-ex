#!/usr/bin/env elixir
# Fetch room metadata and stream URLs.
# Usage: mix run examples/stream_info.exs <username> [cookies]

args = System.argv()
username = Enum.at(args, 0) || raise "usage: stream_info.exs <username> [cookies]"
cookies = Enum.at(args, 1)

case PirateTok.Live.check_online(username) do
  {:ok, room_id} ->
    IO.puts("=== Room Info ===")
    IO.puts("Username: @#{username}")
    IO.puts("Room ID:  #{room_id}")

    opts = if cookies, do: [cookies: cookies], else: []

    case PirateTok.Live.fetch_room_info(room_id, opts) do
      {:ok, info} ->
        IO.puts("Title:    #{info.title}")
        IO.puts("Viewers:  #{info.viewers}")
        IO.puts("Likes:    #{info.likes}")
        IO.puts("Total:    #{info.total_viewers}")

        if info.stream_url do
          IO.puts("\n=== Stream URLs (FLV) ===")
          if info.stream_url.flv_origin, do: IO.puts("Origin: #{info.stream_url.flv_origin}")
          if info.stream_url.flv_hd, do: IO.puts("HD:     #{info.stream_url.flv_hd}")
          if info.stream_url.flv_sd, do: IO.puts("SD:     #{info.stream_url.flv_sd}")
          if info.stream_url.flv_ld, do: IO.puts("LD:     #{info.stream_url.flv_ld}")
          if info.stream_url.flv_ao, do: IO.puts("Audio:  #{info.stream_url.flv_ao}")
        end

      {:error, err} ->
        IO.puts("Room info failed: #{err.message}")

        if err.type == :age_restricted do
          IO.puts("Hint: pass session cookies as the second argument")
        end
    end

  {:error, err} ->
    IO.puts("Error: #{err.message}")
    System.halt(1)
end
