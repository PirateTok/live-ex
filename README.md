<p align="center">
  <img src="https://raw.githubusercontent.com/PirateTok/.github/main/profile/assets/og-banner-v2.png" alt="PirateTok" width="640" />
</p>

# piratetok_live

Connect to any TikTok Live stream and receive real-time events in Elixir. No signing server, no API keys, no authentication required.

```elixir
# Connect and stream events to the calling process
{:ok, pid} = PirateTok.Live.connect("username_here")

# Events arrive as messages — pattern match on the type
receive do
  {:tiktok_live, :chat, msg} ->
    IO.puts("[chat] #{msg.user.nickname}: #{msg.comment}")

  {:tiktok_live, :gift, msg} ->
    IO.puts("[gift] #{msg.user.nickname} sent #{msg.gift.name} x#{msg.repeat_count}")

  {:tiktok_live, :like, msg} ->
    IO.puts("[like] #{msg.user.nickname} (#{msg.total_likes} total)")

  {:tiktok_live, :disconnected, _} ->
    IO.puts("stream ended")
end
```

## Install

```elixir
def deps do
  [
    {:piratetok_live, "~> 0.1.5"}
  ]
end
```

Requires Elixir >= 1.15.

## Other languages

| Language | Install | Repo |
|:---------|:--------|:-----|
| **Rust** | `cargo add piratetok-live-rs` | [live-rs](https://github.com/PirateTok/live-rs) |
| **Go** | `go get github.com/PirateTok/live-go` | [live-go](https://github.com/PirateTok/live-go) |
| **Python** | `pip install piratetok-live-py` | [live-py](https://github.com/PirateTok/live-py) |
| **JavaScript** | `npm install piratetok-live-js` | [live-js](https://github.com/PirateTok/live-js) |
| **C#** | `dotnet add package PirateTok.Live` | [live-cs](https://github.com/PirateTok/live-cs) |
| **Java** | `com.piratetok:live` | [live-java](https://github.com/PirateTok/live-java) |
| **Lua** | `luarocks install piratetok-live-lua` | [live-lua](https://github.com/PirateTok/live-lua) |
| **Dart** | `dart pub add piratetok_live` | [live-dart](https://github.com/PirateTok/live-dart) |
| **C** | `#include "piratetok.h"` | [live-c](https://github.com/PirateTok/live-c) |
| **PowerShell** | `Install-Module PirateTok.Live` | [live-ps1](https://github.com/PirateTok/live-ps1) |
| **Shell** | `bpkg install PirateTok/live-sh` | [live-sh](https://github.com/PirateTok/live-sh) |

## Features

- **Zero signing dependency** -- no API keys, no signing server, no external auth
- **65 decoded event types** -- protobuf DSL modules via `protobuf` hex package, no codegen
- **GenServer-based** -- events delivered as process messages `{:tiktok_live, type, data}`
- **Auto-reconnection** -- stale detection, exponential backoff, self-healing auth
- **Enriched User data** -- badges, gifter level, moderator status, follow info, fan club
- **Sub-routed convenience events** -- `:follow`, `:share`, `:join`, `:live_ended` fire alongside raw events
- **DEVICE_BLOCKED handling** -- detects blocked ttwid at WSS handshake, auto-rotates with 2s retry
- **Proxy support** -- HTTP CONNECT proxy (optional Basic auth) for all HTTP and WSS connections; SOCKS is not supported
- **Helpers** -- `ProfileCache` (TTL-cached sigi scrape), `GiftStreakTracker` (combo deltas), `LikeAccumulator` (monotonic likes)

## Configuration

```elixir
{:ok, pid} = PirateTok.Live.connect("username_here",
  cdn: :eu,                  # :eu / :us / :global (default)
  timeout: 15_000,           # HTTP timeout in ms (default 10_000)
  heartbeat_interval: 10_000, # ms between heartbeats (default 10_000)
  stale_timeout: 90_000,     # reconnect after N ms of silence (default 60_000)
  max_retries: 10,           # consecutive failed reconnects before giving up (default 5)
  proxy: "http://user:pass@host:port", # HTTP CONNECT proxy, Basic auth optional (SOCKS rejected)
  compress: false,           # disable gzip compression for WSS payloads (default true)
  user_agent: "Mozilla/...", # override random UA rotation with a fixed user-agent
  cookies: "sessionid=xxx; sid_tt=xxx", # session cookies for 18+ room info
  language: "en",            # override detected system language (two-letter code)
  region: "US"               # override detected system region (two-letter code)
)
```

## Room info (optional, separate call)

```elixir
# Check if user is live -- anchor_id is the streamer's user id
{:ok, %{room_id: room_id, anchor_id: anchor_id}} = PirateTok.Live.check_online("username_here")

# Fetch room metadata (title, viewers, stream URLs)
{:ok, info} = PirateTok.Live.fetch_room_info(room_id)

# 18+ rooms -- pass session cookies from browser DevTools
{:ok, info} = PirateTok.Live.fetch_room_info(room_id,
  cookies: "sessionid=abc; sid_tt=abc")
```

`check_online/2` errors: `:user_not_found`, `:host_not_online`, `:api_error` (statusCode in the message), `:tiktok_blocked` (HTTP 403/429, empty or non-JSON body).

## Top viewers (WSS, no cookies)

```elixir
{:tiktok_live, :room_user_seq, seq} ->
  for c <- PirateTok.Live.top_viewers(seq), do: IO.puts("#{c.rank} #{c.user.nickname} #{c.score}")
```

`:room_user_seq` carries `viewer_count`, `total_user`, `anonymous`, `pop_str`, `ranks_list`, `seats_list`.

## Audience roster (optional, login-gated)

The full viewer list behind the web viewer panel. Session cookies are **required for this call only** -- without them you get an error of type `:session_required`.

```elixir
{:ok, aud} = PirateTok.Live.fetch_room_audience(room_id, anchor_id,
  cookies: "sessionid=abc; sid_tt=abc")
# aud.total, aud.anonymous, aud.viewers (rank, score, user_id, username, nickname, ...)
```

Pass `nil` as `anchor_id` to resolve it via room info (one extra request).

## How it works

1. Resolves username to room ID via TikTok JSON API
2. Authenticates and opens a direct WSS connection
3. Sends protobuf heartbeats every 10s to keep alive
4. Decodes protobuf event stream into Elixir structs
5. Auto-reconnects on stale/dropped connections, reusing the ttwid + UA (ttwid fetch retried up to 8x, 750 ms apart); rotates them only on DEVICE_BLOCKED or a session that died within 30 s. A session that stayed up 30 s resets the retry counter

All protobuf schemas are defined via `use Protobuf` field declarations -- no `.proto` files, no codegen.

## Examples

```bash
mix run examples/basic_chat.exs <username>       # connect + print chat events
mix run examples/online_check.exs <username>     # check if user is live
mix run examples/stream_info.exs <username>      # fetch room metadata + stream URLs
mix run examples/gift_tracker.exs <username>     # track gifts with diamond totals
mix run examples/gift_streak.exs <username>      # gift streak tracker with per-event deltas
mix run examples/profile_lookup.exs [username]   # fetch profile metadata + avatars
mix run examples/audience.exs <username> <cookies> # full viewer roster (session cookies required)
```

## Replay testing

Deterministic cross-lib validation against binary WSS captures. Requires testdata from a separate repo:

```bash
git clone https://github.com/PirateTok/live-testdata ../live-testdata
mix test
```

Missing testdata is a test failure, not a skip. Lookup order: `$PIRATETOK_TESTDATA`, `testdata/`, `../live-testdata/` (manifests in `manifests/` or `captures/manifests/`). The `_raw` captures are not in live-testdata -- supply them via `testdata/` or `PIRATETOK_TESTDATA`.

`mix test` also runs `test/pirate_tok/parity_test.exs` -- offline tests for ttwid retry (local fake HTTP responder), reconnect policy, `ranks_list`/`top_viewers`, audience parsing, gift helpers and `check_online` error mapping.

## License

0BSD
