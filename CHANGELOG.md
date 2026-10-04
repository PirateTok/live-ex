# Changelog

## 0.2.1

- **Fix: proxies actually work.** HTTP requests passed `https_proxy` as a per-request option, which `:httpc` ignores (requests went direct); proxies are now set on a per-proxy httpc profile. Proxied WSS sent the WebSocket upgrade outside the CONNECT tunnel; it now waits for `gun_tunnel_up` and upgrades with `tunnel: stream_ref`.
- Proxy auth: `http://user:pass@host:port` → `Proxy-Authorization: Basic` on HTTP (httpc `proxy_auth`) and the WSS CONNECT (gun `username`/`password`). SOCKS URLs are rejected with `:invalid_url` (README no longer claims SOCKS5).
- Locale (`:language` / `:region`) now reaches `check_online` from the client.
- Tests: `wire_test.exs` drives the real client through a local Basic-auth CONNECT proxy + TLS fake (generated CA): room/ttwid/WSS tunnels, UA / cookies / locale / compress / heartbeat on the wire, heartbeat + enter_room frames; ack and room-info parsing fixtures.

## 0.2.0 (tagged, not on Hex — publish blocked on interactive auth)

- ttwid fetch retries up to 8× (750 ms apart) when tiktok.com answers without the cookie; transport errors fail fast.
- Reconnect loop: ttwid + UA reused across reconnects, rotated only on DEVICE_BLOCKED or a session that died within 30 s. A ttwid failure is a failed attempt (`:reconnecting` fires) instead of stopping the client.
- `max_retries` counts consecutive failures — a session that stayed up 30 s resets the counter. `:reconnecting` carries `device_blocked`.
- WSS `heartbeat_duration` URL param follows `:heartbeat_interval`.
- **Breaking:** `check_online/2` returns `{:ok, %{room_id, anchor_id}}`. Non-zero statusCode → `:api_error`; empty / non-JSON body → `:tiktok_blocked`. Honors `:language` / `:region` opts.
- `:room_user_seq` decodes `ranks_list`, `seats_list`, `pop_str`, `anonymous`; new `PirateTok.Live.top_viewers/1`.
- New `PirateTok.Live.fetch_room_audience/3` — full viewer roster, login-gated; new `:session_required` error. `examples/audience.exs`.
- Gift helpers exposed: `PirateTok.Live.is_combo_gift/1`, `is_streak_over/1`, `diamond_total/1`.
- Replay tests fail (instead of skip) on missing testdata, also look in `../live-testdata`; new offline `parity_test.exs`.
- Homepage: https://piratetok.rosint.org
