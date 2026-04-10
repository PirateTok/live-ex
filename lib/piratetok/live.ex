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

      {:ok, room_id} = PirateTok.Live.check_online("some_username")
      {:ok, info} = PirateTok.Live.fetch_room_info(room_id)

  For 18+ rooms, pass session cookies:

      {:ok, info} = PirateTok.Live.fetch_room_info(room_id, cookies: "sessionid=abc; sid_tt=abc")
  """

  alias PirateTok.Live.Client
  alias PirateTok.Live.Http.Api

  @doc """
  Check if a TikTok user is currently live.

  Returns `{:ok, room_id}` or `{:error, %PirateTok.Live.Error{}}`.
  """
  @spec check_online(String.t(), keyword()) :: {:ok, String.t()} | {:error, PirateTok.Live.Error.t()}
  defdelegate check_online(username, opts \\ []), to: Api

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
  - `:max_retries` — reconnection attempts (default 5)
  - `:user_agent` — override random UA pool
  - `:cookies` — session cookies for WSS (appended alongside ttwid)
  - `:proxy` — HTTP/HTTPS proxy URL for ttwid fetch and API calls (e.g. `"http://host:port"`)
  """
  @spec connect(String.t(), keyword()) :: GenServer.on_start()
  def connect(username, opts \\ []) do
    Client.start_link(username, opts)
  end

  @doc "Stop a running connection."
  @spec disconnect(GenServer.server()) :: :ok
  def disconnect(pid), do: Client.stop(pid)
end
