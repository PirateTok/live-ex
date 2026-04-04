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
  alias PirateTok.Live.Connection.{Url, Wss}
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
    attempt: 0
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
      cookies: Keyword.get(opts, :cookies)
    }

    send(self(), :resolve_and_connect)
    {:ok, state}
  end

  @impl true
  def handle_info(:resolve_and_connect, state) do
    ua = state.user_agent || UA.random_ua()

    case Api.check_online(state.username, user_agent: ua, timeout: state.timeout) do
      {:ok, room_id} ->
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
    ua = state.user_agent || UA.random_ua()

    case Ttwid.fetch(user_agent: ua, timeout: state.timeout) do
      {:ok, ttwid} ->
        tz = UA.system_timezone()
        cdn_host = Url.cdn_host(state.cdn)
        ws_url = Url.build(cdn_host, state.room_id, tz)

        ws_cookie =
          case state.cookies do
            nil -> "ttwid=#{ttwid}"
            extra -> "ttwid=#{ttwid}; #{extra}"
          end

        caller = state.caller

        callback = fn type, data ->
          send(caller, {:tiktok_live, type, data})
        end

        task =
          Task.async(fn ->
            Wss.connect(ws_url, ws_cookie, ua, state.room_id,
              heartbeat_interval: state.heartbeat_interval,
              stale_timeout: state.stale_timeout,
              callback: callback
            )
          end)

        {:noreply, %{state | ws_task: task}}

      {:error, err} ->
        Logger.error("ttwid fetch failed: #{err.message}")
        send_event(state.caller, :error, err)
        {:stop, :normal, state}
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
    is_device_blocked =
      case result do
        {:error, %Error{type: :device_blocked}} -> true
        _ -> false
      end

    if is_device_blocked do
      Logger.warning("DEVICE_BLOCKED — rotating ttwid + UA")
    end

    attempt = state.attempt + 1

    if attempt > state.max_retries do
      Logger.info("max retries (#{state.max_retries}) exceeded")
      send_event(state.caller, :disconnected, nil)
      {:stop, :normal, %{state | attempt: attempt}}
    else
      delay_ms = if is_device_blocked, do: 2_000, else: min(1_000 * round(:math.pow(2, attempt)), 30_000)

      send_event(state.caller, :reconnecting, %{
        attempt: attempt,
        max_retries: state.max_retries,
        delay_secs: div(delay_ms, 1000)
      })

      Logger.info("reconnecting in #{div(delay_ms, 1000)}s (attempt #{attempt}/#{state.max_retries})")
      Process.send_after(self(), :reconnect, delay_ms)
      {:noreply, %{state | attempt: attempt, ws_task: nil}}
    end
  end

  defp send_event(caller, type, data) do
    send(caller, {:tiktok_live, type, data})
  end
end
