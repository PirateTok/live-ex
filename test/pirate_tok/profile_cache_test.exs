defmodule PirateTok.ProfileCacheTest do
  # F16 offline: ProfileCache against a local origin (injected :base_url) that counts hits
  # per path — SIGI parse, cache hits, negative caching, single ttwid fetch.
  use ExUnit.Case, async: true

  alias PirateTok.Live.Helpers.ProfileCache
  alias PirateTok.Live.Http.Sigi

  defp sigi(detail) do
    json = Jason.encode!(%{"__DEFAULT_SCOPE__" => %{"webapp.user-detail" => detail}})
    ~s(<html><script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">#{json}</script></html>)
  end

  @someone_detail %{
             "statusCode" => 0,
             "userInfo" => %{
               "user" => %{
                 "id" => "6900000000000000001",
                 "uniqueId" => "someone",
                 "nickname" => "Some One",
                 "signature" => "bio here",
                 "avatarLarger" => "https://p16/l.jpg",
                 "verified" => true,
                 "privateAccount" => false,
                 "roomId" => "7300000000000000002",
                 "bioLink" => %{"link" => "piratetok.rosint.org"}
               },
               "stats" => %{"followerCount" => 10, "followingCount" => 2, "heartCount" => 99, "videoCount" => 3, "friendCount" => 1}
             }
           }

  defp someone_html, do: sigi(@someone_detail)

  defp start_origin do
    {:ok, ls} = :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(ls)
    test_pid = self()
    spawn_link(fn -> serve(ls, test_pid) end)
    "http://127.0.0.1:#{port}/"
  end

  defp serve(ls, test_pid) do
    {:ok, s} = :gen_tcp.accept(ls)
    {:ok, req} = :gen_tcp.recv(s, 0, 5_000)
    [_method, path | _] = String.split(req, " ", parts: 3)
    send(test_pid, {:hit, path, req})

    {cookie, body} =
      case path do
        "/" -> {"Set-Cookie: ttwid=1%7Corigin%7C7; Path=/\r\n", "ok"}
        "/@someone" -> {"", someone_html()}
        "/@privy" -> {"", sigi(%{"statusCode" => 10222})}
        "/@ghost" -> {"", sigi(%{"statusCode" => 10221})}
        _ -> {"", "nope"}
      end

    :gen_tcp.send(s, "HTTP/1.1 200 OK\r\n#{cookie}Content-Length: #{byte_size(body)}\r\nConnection: close\r\n\r\n#{body}")
    :gen_tcp.close(s)
    serve(ls, test_pid)
  end

  defp hits(acc \\ %{}) do
    receive do
      {:hit, path, _req} -> hits(Map.update(acc, path, 1, &(&1 + 1)))
    after
      100 -> acc
    end
  end

  test "parse_profile: SIGI fields" do
    assert {:ok, p} = Sigi.parse_profile(someone_html(), "someone")
    assert {p.user_id, p.unique_id, p.nickname, p.bio} == {"6900000000000000001", "someone", "Some One", "bio here"}
    assert {p.verified, p.private_account, p.room_id, p.bio_link} == {true, false, "7300000000000000002", "piratetok.rosint.org"}
    assert {p.follower_count, p.following_count, p.heart_count, p.video_count, p.friend_count} == {10, 2, 99, 3, 1}
    assert {:error, %{type: :profile_scrape}} = Sigi.parse_profile("<html>no sigi</html>", "x")
  end

  test "fetch: parse + cache hit (origin hit once) + ttwid fetched once" do
    {:ok, cache} = ProfileCache.start_link(base_url: start_origin(), user_agent: "UA-Test/1")
    assert {:ok, %{unique_id: "someone", follower_count: 10}} = ProfileCache.fetch(cache, "@SomeOne")
    assert {:ok, %{unique_id: "someone"}} = ProfileCache.fetch(cache, "someone")
    assert %{unique_id: "someone"} = ProfileCache.cached(cache, "someone")
    assert hits() == %{"/" => 1, "/@someone" => 1}
  end

  test "fetch: private (10222) and not-found (10221) are negatively cached" do
    {:ok, cache} = ProfileCache.start_link(base_url: start_origin())
    assert {:error, %{type: :profile_private}} = ProfileCache.fetch(cache, "privy")
    assert {:error, %{type: :profile_private}} = ProfileCache.fetch(cache, "privy")
    assert {:error, %{type: :profile_not_found}} = ProfileCache.fetch(cache, "ghost")
    assert {:error, %{type: :profile_not_found}} = ProfileCache.fetch(cache, "ghost")
    assert ProfileCache.cached(cache, "privy") == nil
    assert hits() == %{"/" => 1, "/@privy" => 1, "/@ghost" => 1}
  end

  test "invalidate: next fetch goes back to the origin, ttwid still reused" do
    {:ok, cache} = ProfileCache.start_link(base_url: start_origin())
    assert {:ok, _} = ProfileCache.fetch(cache, "someone")
    :ok = ProfileCache.invalidate(cache, "someone")
    assert {:ok, _} = ProfileCache.fetch(cache, "someone")
    assert hits() == %{"/" => 1, "/@someone" => 2}
  end
end
