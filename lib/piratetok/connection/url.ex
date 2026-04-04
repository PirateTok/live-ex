defmodule PirateTok.Live.Connection.Url do
  @moduledoc false

  @cdn_hosts %{
    eu: "webcast-ws.eu.tiktok.com",
    us: "webcast-ws.us.tiktok.com",
    global: "webcast-ws.tiktok.com"
  }

  @spec cdn_host(atom()) :: String.t()
  def cdn_host(cdn), do: Map.get(@cdn_hosts, cdn, @cdn_hosts.global)

  @spec build(String.t(), String.t(), String.t()) :: String.t()
  def build(cdn_host, room_id, tz) do
    last_rtt = :erlang.float_to_binary(100.0 + :rand.uniform() * 100.0, decimals: 3)

    params = [
      {"version_code", "180800"},
      {"device_platform", "web"},
      {"cookie_enabled", "true"},
      {"screen_width", "1920"},
      {"screen_height", "1080"},
      {"browser_language", "en-US"},
      {"browser_platform", "Linux x86_64"},
      {"browser_name", "Mozilla"},
      {"browser_version", "5.0 (X11)"},
      {"browser_online", "true"},
      {"tz_name", tz},
      {"app_name", "tiktok_web"},
      {"sup_ws_ds_opt", "1"},
      {"update_version_code", "2.0.0"},
      {"compress", "gzip"},
      {"webcast_language", "en"},
      {"ws_direct", "1"},
      {"aid", "1988"},
      {"live_id", "12"},
      {"app_language", "en"},
      {"client_enter", "1"},
      {"room_id", room_id},
      {"identity", "audience"},
      {"history_comment_count", "6"},
      {"last_rtt", last_rtt},
      {"heartbeat_duration", "10000"},
      {"resp_content_type", "protobuf"},
      {"did_rule", "3"}
    ]

    query = Enum.map_join(params, "&", fn {k, v} -> "#{URI.encode(k)}=#{URI.encode(v)}" end)
    "wss://#{cdn_host}/webcast/im/ws_proxy/ws_reuse_supplement/?#{query}"
  end
end
