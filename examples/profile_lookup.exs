# Profile lookup example — fetch HD avatars + profile metadata.
# Usage: mix run examples/profile_lookup.exs [username]

alias PirateTok.Live.Helpers.ProfileCache

username = List.first(System.argv(), "tiktok")

{:ok, cache} = ProfileCache.start_link()

IO.puts("Fetching profile for @#{username}...")

case ProfileCache.fetch(cache, username) do
  {:ok, p} ->
    room = if p.room_id == "", do: "(offline)", else: p.room_id
    bio = p.bio_link || "(none)"

    IO.puts("  User ID:    #{p.user_id}")
    IO.puts("  Nickname:   #{p.nickname}")
    IO.puts("  Verified:   #{p.verified}")
    IO.puts("  Followers:  #{p.follower_count}")
    IO.puts("  Videos:     #{p.video_count}")
    IO.puts("  Avatar (thumb):  #{p.avatar_thumb}")
    IO.puts("  Avatar (720):    #{p.avatar_medium}")
    IO.puts("  Avatar (1080):   #{p.avatar_large}")
    IO.puts("  Bio link:   #{bio}")
    IO.puts("  Room ID:    #{room}")

    IO.puts("\nFetching @#{username} again (should be cached)...")

    case ProfileCache.fetch(cache, username) do
      {:ok, p2} ->
        IO.puts("  [cached] #{p2.nickname} — #{p2.follower_count} followers")

      {:error, err} ->
        IO.puts("  [cached error] #{err.message}")
    end

  {:error, err} ->
    IO.puts("  [ERROR] #{err.message}")
end
