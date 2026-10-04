defmodule PirateTok.Live.Client do
  @moduledoc """
  GenServer that connects to a TikTok Live stream and dispatches events.

  Events are sent as messages to the caller process:
  `{:tiktok_live, event_type, event_data}`

  ## Example

      {:ok, pid} = PirateTok.Live.Client.start_link("some_username")

      # Receive events in your process
      receive do
        {:tiktok_live, :chat, msg} ->
          IO.puts("\#{msg.user.nickname}: \#{msg.comment}")
        {:tiktok_live, :disconnected, _} ->
          IO.puts("Stream ended")
      end
  """

  use GenServer
  require Logger

  alias PirateTok.Live.Auth.Ttwid
  alias PirateTok.Live.Connection.{Reconnect, Url, Wss}
  alias PirateTok.Live.Error
  alias PirateTok.Live.Http.{Api, UA}

  defstruct [
    :username,
    :room_id,
    :caller,
    :ws_task,
    cdn: :global,
    timeout: 10_000,
    heartbeat_interval: 10_000,
    stale_timeout: 60_000,
    max_retries: 5,
    user_agent: nil,
    cookies: nil,
    proxy: nil,
    language: nil,
    region: nil,
    compress: true,
    attempt: 0,
    # {ttwid, user_agent} held across reconnects; nil = fetch fresh
    session: nil,
    attempt_started_at: nil,
    # internal: extra opts for the ttwid fetch (tests point :url at a fake)
    ttwid_opts: [],
    # internal: CA certs (DER) replacing the system store — offline wire tests only
    tls_cacerts: nil
  ]

  # -- public API --

  @spec start_link(String.t(), keyword()) :: GenServer.on_start()
  def start_link(username, opts \\ []) do
    GenServer.start_link(__MODULE__, {username, self(), opts})
  end

  @spec stop(GenServer.server()) :: :ok
  def stop(pid), do: GenServer.stop(pid, :normal)

  # -- GenServer callbacks --

  @impl true
  def init({username, caller, opts}) do
    state = %__MODULE__{
      username: username,
      caller: caller,
      cdn: Keyword.get(opts, :cdn, :global),
      timeout: Keyword.get(opts, :timeout, 10_000),
      heartbeat_interval: Keyword.get(opts, :heartbeat_interval, 10_000),
      stale_timeout: Keyword.get(opts, :stale_timeout, 60_000),
      max_retries: Keyword.get(opts, :max_retries, 5),
      user_agent: Keyword.get(opts, :user_agent),
      cookies: Keyword.get(opts, :cookies),
      proxy: Keyword.get(opts, :proxy),
      language: Keyword.get(opts, :language),
      region: Keyword.get(opts, :region),
      compress: Keyword.get(opts, :compress, true),
      ttwid_opts: Keyword.get(opts, :ttwid_opts, []),
      tls_cacerts: Keyword.get(opts, :tls_cacerts)
    }

    send(self(), :resolve_and_connect)
    {:ok, state}
  end

  @impl true
  def handle_info(:resolve_and_connect, state) do
    ua = state.user_agent || UA.random_ua()

    http_opts =
      [user_agent: ua, timeout: state.timeout, language: state.language, region: state.region] ++ transport_opts(state)

    case Api.check_online(state.username, http_opts) do
      {:ok, %{room_id: room_id}} ->
        Logger.info("resolved #{state.username} -> room #{room_id}")
        send_event(state.caller, :connected, %{room_id: room_id})
        state = %{state | room_id: room_id}
        send(self(), :connect_ws)
        {:noreply, state}

      {:error, err} ->
        send_event(state.caller, :error, err)
        {:stop, :normal, state}
    end
  end

  def handle_info(:connect_ws, state) do
    case ensure_session(state) do
      {:ok, {ttwid, ua} = session} ->
        state = %{state | session: session}
        tz = UA.system_timezone()
        lang = state.language || UA.system_language()
        region = state.region || UA.system_region()
        cdn_host = Url.cdn_host(state.cdn)
        ws_url = Url.build(cdn_host, state.room_id, tz, lang, region, state.compress, state.heartbeat_interval)

        ws_cookie =
          case state.cookies do
            nil -> "ttwid=#{ttwid}"
            extra -> "ttwid=#{ttwid}; #{extra}"
          end

        caller = state.caller

        callback = fn type, data ->
          send(caller, {:tiktok_live, type, data})
        end

        ws_opts =
          [
            heartbeat_interval: state.heartbeat_interval,
            stale_timeout: state.stale_timeout,
            callback: callback,
            language: lang,
            region: region
          ] ++ transport_opts(state)

        task =
          Task.async(fn ->
            Wss.connect(ws_url, ws_cookie, ua, state.room_id, ws_opts)
          end)

        {:noreply, %{state | ws_task: task, attempt_started_at: now_ms()}}

      {:error, err} ->
        # a ttwid failure is a failed attempt, never an abort
        Logger.warning("ttwid acquisition failed: #{err.message}")
        attempt_ended(:failed, %{state | session: nil})
    end
  end

  def handle_info(:reconnect, state) do
    send(self(), :connect_ws)
    {:noreply, state}
  end

  def handle_info({ref, result}, %{ws_task: %Task{ref: task_ref}} = state) when ref == task_ref do
    Process.demonitor(ref, [:flush])
    handle_ws_result(result, state)
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, %{ws_task: %Task{pid: task_pid}} = state)
      when pid == task_pid do
    Logger.error("ws task crashed: #{inspect(reason)}")
    handle_ws_result({:error, Error.connection_closed()}, %{state | ws_task: nil})
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp handle_ws_result(result, state) do
    elapsed = now_ms() - (state.attempt_started_at || now_ms())
    outcome = Reconnect.classify(result, elapsed)

    if outcome == :blocked do
      Logger.warning("DEVICE_BLOCKED — rotating ttwid + UA")
    end

    attempt_ended(outcome, %{state | ws_task: nil, attempt_started_at: nil})
  end

  defp attempt_ended(outcome, state) do
    case Reconnect.decide(state.attempt, outcome, state.max_retries) do
      :give_up ->
        Logger.info("max retries (#{state.max_retries}) exceeded")
        send_event(state.caller, :disconnected, nil)
        {:stop, :normal, %{state | attempt: state.attempt + 1}}

      {:retry, attempt, delay_ms, keep_session?} ->
        send_event(state.caller, :reconnecting, %{
          attempt: attempt,
          max_retries: state.max_retries,
          delay_secs: div(delay_ms, 1000),
          device_blocked: outcome == :blocked
        })

        Logger.info("reconnecting in #{div(delay_ms, 1000)}s (attempt #{attempt}/#{state.max_retries})")
        Process.send_after(self(), :reconnect, delay_ms)
        session = if keep_session?, do: state.session, else: nil
        {:noreply, %{state | attempt: attempt, session: session}}
    end
  end

  # ttwid + UA: reuse the held session, else fetch fresh (bounded retry).
  defp ensure_session(%{session: {_, _} = session}), do: {:ok, session}

  defp ensure_session(state) do
    ua = state.user_agent || UA.random_ua()
    opts = [user_agent: ua, timeout: state.timeout] ++ transport_opts(state) ++ state.ttwid_opts

    case Ttwid.fetch_retrying(opts) do
      {:ok, ttwid} -> {:ok, {ttwid, ua}}
      {:error, _} = err -> err
    end
  end

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp send_event(caller, type, data) do
    send(caller, {:tiktok_live, type, data})
  end

  defp transport_opts(state) do
    Enum.reject([proxy: state.proxy, tls_cacerts: state.tls_cacerts], fn {_, v} -> is_nil(v) end)
  end
end
