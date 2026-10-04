defmodule PirateTok.Live do
  @moduledoc """
  Connect to any TikTok Live stream and receive real-time events:
  chat messages, gifts, likes, joins, viewer counts, and more.

  ## Quick start

      {:ok, pid} = PirateTok.Live.connect("some_username")

      loop = fn loop_fn ->
        receive do
          {:tiktok_live, :chat, msg} ->
            IO.puts("\#{msg.user.nickname}: \#{msg.comment}")
            loop_fn.(loop_fn)
          {:tiktok_live, :disconnected, _} ->
            IO.puts("disconnected")
        end
      end

      loop.(loop)

  ## How it works

  1. Resolves the TikTok username to a room ID
  2. Acquires a ttwid cookie (anonymous GET to tiktok.com)
  3. Opens a WebSocket connection and streams protobuf-encoded events

  No signing server, no x_bogus, no msToken. Just ttwid.

  ## Room info (optional)

  Room metadata (title, viewer counts, stream URLs) is a separate call:

      {:ok, %{room_id: room_id}} = PirateTok.Live.check_online("some_username")
      {:ok, info} = PirateTok.Live.fetch_room_info(room_id)

  For 18+ rooms, pass session cookies:

      {:ok, info} = PirateTok.Live.fetch_room_info(room_id, cookies: "sessionid=abc; sid_tt=abc")
  """

  alias PirateTok.Live.Client
  alias PirateTok.Live.Http.Api
  alias PirateTok.Live.Proto.{WebcastGiftMessage, WebcastRoomUserSeqMessage}

  @doc """
  Check if a TikTok user is currently live.

  Returns `{:ok, %{room_id: room_id, anchor_id: anchor_id}}` (`anchor_id` is the
  streamer's user id, used by `fetch_room_audience/3`) or `{:error, %PirateTok.Live.Error{}}`.
  """
  @spec check_online(String.t(), keyword()) ::
          {:ok, %{room_id: String.t(), anchor_id: String.t() | nil}} | {:error, PirateTok.Live.Error.t()}
  defdelegate check_online(username, opts \\ []), to: Api

  @doc """
  Fetch the full audience roster — every named viewer currently in the room
  (the web viewer panel, not just the top-3 box; for that see `top_viewers/1`).

  **Login-gated**: pass `cookies: "sessionid=xxx; sid_tt=xxx"` — cookies are
  required for this call only. Without them you get an error of type
  `:session_required`.

  `anchor_id` comes from `check_online/2`; pass `nil` to resolve it via room
  info (one extra request).

  Returns `{:ok, %PirateTok.Live.Http.Audience{total, anonymous, viewers, raw_json}}`.
  """
  @spec fetch_room_audience(String.t(), String.t() | nil, keyword()) ::
          {:ok, PirateTok.Live.Http.Audience.t()} | {:error, PirateTok.Live.Error.t()}
  defdelegate fetch_room_audience(room_id, anchor_id, opts \\ []), to: Api

  @doc """
  Top viewers from a `:room_user_seq` event: `ranks_list` entries with a
  decoded user, sorted by rank. No cookies needed.
  """
  @spec top_viewers(WebcastRoomUserSeqMessage.t()) :: [PirateTok.Live.Proto.Contributor.t()]
  defdelegate top_viewers(seq), to: WebcastRoomUserSeqMessage

  @doc "Gift helpers on a `:gift` event: combo detection, streak end, diamond value."
  @spec is_combo_gift(WebcastGiftMessage.t()) :: boolean()
  defdelegate is_combo_gift(gift), to: WebcastGiftMessage
  @spec is_streak_over(WebcastGiftMessage.t()) :: boolean()
  defdelegate is_streak_over(gift), to: WebcastGiftMessage
  @spec diamond_total(WebcastGiftMessage.t()) :: non_neg_integer()
  defdelegate diamond_total(gift), to: WebcastGiftMessage

  @doc """
  Fetch room metadata: title, viewer counts, stream URLs.

  This is an **optional** call — not needed for WSS event streaming.
  For 18+ rooms, pass `cookies: "sessionid=xxx; sid_tt=xxx"`.
  """
  @spec fetch_room_info(String.t(), keyword()) :: {:ok, map()} | {:error, PirateTok.Live.Error.t()}
  defdelegate fetch_room_info(room_id, opts \\ []), to: Api

  @doc """
  Connect to a TikTok Live stream and receive events.

  Starts a GenServer that resolves the username, connects via WSS, and sends
  events as `{:tiktok_live, event_type, event_data}` messages to the calling process.

  ## Options

  - `:cdn` — `:global` (default), `:eu`, or `:us`
  - `:timeout` — HTTP timeout in ms (default 10_000)
  - `:heartbeat_interval` — WSS heartbeat in ms (default 10_000)
  - `:stale_timeout` — close if no data for this long (default 60_000)
  - `:max_retries` — consecutive failed reconnects before giving up (default 5);
    a session that stayed up 30 s resets the counter. ttwid + UA are reused
    across reconnects and rotated only on DEVICE_BLOCKED or a session that
    died within 30 s
  - `:user_agent` — override random UA pool
  - `:cookies` — session cookies for WSS (appended alongside ttwid)
  - `:proxy` — HTTP/HTTPS proxy URL for all HTTP and WSS connections (e.g. `"http://host:port"`)
  - `:language` — override detected system language (e.g. `"en"`, `"ro"`)
  - `:region` — override detected system region (e.g. `"US"`, `"RO"`)
  """
  @spec connect(String.t(), keyword()) :: GenServer.on_start()
  def connect(username, opts \\ []) do
    Client.start_link(username, opts)
  end

  @doc "Stop a running connection."
  @spec disconnect(GenServer.server()) :: :ok
  def disconnect(pid), do: Client.stop(pid)
end
