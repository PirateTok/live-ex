# Changelog

## 0.2.0

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
