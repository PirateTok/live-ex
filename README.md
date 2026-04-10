<p align="center">
  <img src="https://raw.githubusercontent.com/PirateTok/.github/main/profile/assets/og-banner-v2.png" alt="PirateTok" width="640" />
</p>

# piratetok_live

Connect to any TikTok Live stream and receive real-time events in Elixir. No signing server, no API keys, no authentication required.

```elixir
# Start a GenServer that connects and streams events to the calling process
{:ok, pid} = PirateTok.Live.Client.start_link("username_here")

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
    {:piratetok_live, "~> 0.1.0"}
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
- **64 decoded event types** -- protobuf DSL modules via `protobuf` hex package, no codegen
- **GenServer-based** -- events delivered as process messages `{:tiktok_live, type, data}`
- **Auto-reconnection** -- stale detection, exponential backoff, self-healing auth
- **Enriched User data** -- badges, gifter level, moderator status, follow info, fan club
- **Sub-routed convenience events** -- `:follow`, `:share`, `:join`, `:live_ended` fire alongside raw events

## Configuration

```elixir
{:ok, pid} = PirateTok.Live.Client.start_link("username_here",
  cdn: :eu,                  # :eu / :us / :global (default)
  timeout: 15_000,           # HTTP timeout in ms (default 10_000)
  max_retries: 10,           # reconnect attempts (default 5)
  stale_timeout: 90_000      # reconnect after N ms of silence (default 60_000)
)
```

## Room info (optional, separate call)

```elixir
# Check if user is live
{:ok, room_id} = PirateTok.Live.Http.Api.check_online("username_here")

# Fetch room metadata (title, viewers, stream URLs)
{:ok, info} = PirateTok.Live.Http.Api.fetch_room_info(room_id)

# 18+ rooms -- pass session cookies from browser DevTools
{:ok, info} = PirateTok.Live.Http.Api.fetch_room_info(room_id,
  cookies: "sessionid=abc; sid_tt=abc")
```

## How it works

1. Resolves username to room ID via TikTok JSON API
2. Authenticates and opens a direct WSS connection
3. Sends protobuf heartbeats every 10s to keep alive
4. Decodes protobuf event stream into Elixir structs
5. Auto-reconnects on stale/dropped connections with fresh credentials

All protobuf schemas are defined via `use Protobuf` field declarations -- no `.proto` files, no codegen.

## Examples

```bash
mix run examples/basic_chat.exs <username>       # connect + print chat events
mix run examples/online_check.exs <username>     # check if user is live
mix run examples/stream_info.exs <username>      # fetch room metadata + stream URLs
mix run examples/gift_tracker.exs <username>     # track gifts with diamond totals
```

## Replay testing

Deterministic cross-lib validation against binary WSS captures. Requires testdata from a separate repo:

```bash
git clone https://github.com/PirateTok/live-testdata testdata
mix test
```

Tests skip gracefully if testdata is not found. You can also set `PIRATETOK_TESTDATA` to point to a custom location.

## Known gaps

- Explicit `DEVICE_BLOCKED` handshake handling is not implemented yet.
- Proxy support is not implemented yet.

## License

0BSD
