defmodule PirateTok.Live.Connection.Wss do
  @moduledoc false
  # Single WSS connection using :gun. Connects once, streams events to caller,
  # returns on close/stale/error. The client wraps this in a retry loop.

  require Logger

  alias PirateTok.Live.Connection.Frames
  alias PirateTok.Live.Error
  alias PirateTok.Live.Events.Mapper
  alias PirateTok.Live.Http.Client
  alias PirateTok.Live.Proto.{WebcastPushFrame, WebcastResponse}

  @spec connect(String.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, :normal} | {:error, Error.t()}
  def connect(ws_url, cookies, user_agent, room_id, opts \\ []) do
    heartbeat_ms = Keyword.get(opts, :heartbeat_interval, 10_000)
    stale_ms = Keyword.get(opts, :stale_timeout, 60_000)
    callback = Keyword.fetch!(opts, :callback)
    proxy = Keyword.get(opts, :proxy)
    language = Keyword.get(opts, :language, "en")
    region = Keyword.get(opts, :region, "US")

    uri = URI.parse(ws_url)
    host = String.to_charlist(uri.host)
    port = uri.port || 443
    path = "#{uri.path}?#{uri.query}"

    tls_opts = Client.tls_opts("https://#{uri.host}/", opts)

    case open_connection(proxy, host, port, tls_opts) do
      {:ok, conn_pid, upgrade_opts} ->
        headers = ws_headers(uri.host, cookies, user_agent, language, region)
        # through a proxy the upgrade must ride the CONNECT tunnel stream
        stream_ref = :gun.ws_upgrade(conn_pid, path, headers, upgrade_opts)
        run_upgrade(conn_pid, stream_ref, room_id, heartbeat_ms, stale_ms, callback)

      {:error, _} = err ->
        err
    end
  end

  defp open_connection(nil, host, port, tls_opts) do
    open_connection("", host, port, tls_opts)
  end

  defp open_connection("", host, port, tls_opts) do
    gun_opts = %{
      protocols: [:http],
      transport: :tls,
      tls_opts: tls_opts
    }

    case :gun.open(host, port, gun_opts) do
      {:ok, conn_pid} ->
        case :gun.await_up(conn_pid, 10_000) do
          {:ok, _protocol} ->
            {:ok, conn_pid, %{}}

          {:error, reason} ->
            :gun.close(conn_pid)
            {:error, Error.http_error("gun await_up failed: #{inspect(reason)}")}
        end

      {:error, reason} ->
        {:error, Error.http_error("gun open failed: #{inspect(reason)}")}
    end
  end

  defp open_connection(proxy_url, host, port, tls_opts) do
    with {:ok, {proxy_host, proxy_port, creds}} <- Client.parse_proxy(proxy_url) do
      open_tunnel(proxy_host, proxy_port, creds, host, port, tls_opts)
    end
  end

  defp open_tunnel(proxy_host, proxy_port, creds, host, port, tls_opts) do
    # Open a TCP connection to the proxy (no TLS to proxy itself)
    gun_opts = %{protocols: [:http], transport: :tcp}

    case :gun.open(proxy_host, proxy_port, gun_opts) do
      {:ok, conn_pid} ->
        case :gun.await_up(conn_pid, 10_000) do
          {:ok, _protocol} ->
            # CONNECT tunnel; gun sends Proxy-Authorization: Basic when username is set
            connect_dest = %{host: host, port: port, protocols: [:http], transport: :tls, tls_opts: tls_opts}

            connect_dest =
              case creds do
                nil -> connect_dest
                {user, pass} -> Map.merge(connect_dest, %{username: user, password: pass})
              end

            stream_ref = :gun.connect(conn_pid, connect_dest)

            case :gun.await(conn_pid, stream_ref, 10_000) do
              {:response, _fin, 200, _headers} ->
                await_tunnel(conn_pid, stream_ref)

              {:response, _fin, status, _headers} ->
                :gun.close(conn_pid)
                {:error, Error.http_error("proxy CONNECT rejected: HTTP #{status}")}

              {:error, reason} ->
                :gun.close(conn_pid)
                {:error, Error.http_error("proxy CONNECT failed: #{inspect(reason)}")}
            end

          {:error, reason} ->
            :gun.close(conn_pid)
            {:error, Error.http_error("proxy connection failed: #{inspect(reason)}")}
        end

      {:error, reason} ->
        {:error, Error.http_error("proxy open failed: #{inspect(reason)}")}
    end
  end

  # CONNECT accepted: wait until gun has the TLS session up inside the tunnel
  defp await_tunnel(conn_pid, stream_ref) do
    receive do
      {:gun_tunnel_up, ^conn_pid, ^stream_ref, _protocol} ->
        {:ok, conn_pid, %{tunnel: stream_ref}}

      {:gun_error, ^conn_pid, ^stream_ref, reason} ->
        :gun.close(conn_pid)
        {:error, Error.http_error("proxy tunnel failed: #{inspect(reason)}")}

      {:gun_down, ^conn_pid, _protocol, reason, _killed} ->
        {:error, Error.http_error("proxy tunnel down: #{inspect(reason)}")}
    after
      10_000 ->
        :gun.close(conn_pid)
        {:error, Error.http_error("proxy tunnel TLS timeout")}
    end
  end

  defp run_upgrade(conn_pid, stream_ref, room_id, heartbeat_ms, stale_ms, callback) do
    receive do
      {:gun_upgrade, ^conn_pid, ^stream_ref, ["websocket"], resp_headers} ->
        check_handshake_headers(resp_headers, conn_pid, stream_ref, room_id, heartbeat_ms, stale_ms, callback)

      {:gun_response, ^conn_pid, ^stream_ref, _fin, status, resp_headers} ->
        :gun.close(conn_pid)
        handshake_msg = header_value(resp_headers, "handshake-msg")

        if handshake_msg == "DEVICE_BLOCKED" do
          {:error, Error.device_blocked()}
        else
          handshake_status = header_value(resp_headers, "handshake-status")

          {:error,
           Error.invalid_response(
             "handshake rejected: http=#{status} msg=#{handshake_msg} status=#{handshake_status}"
           )}
        end

      {:gun_error, ^conn_pid, ^stream_ref, reason} ->
        :gun.close(conn_pid)
        {:error, Error.http_error("ws upgrade error: #{inspect(reason)}")}
    after
      10_000 ->
        :gun.close(conn_pid)
        {:error, Error.http_error("ws upgrade timeout")}
    end
  end

  defp check_handshake_headers(resp_headers, conn_pid, stream_ref, room_id, heartbeat_ms, stale_ms, callback) do
    handshake_msg = header_value(resp_headers, "handshake-msg")

    if handshake_msg == "DEVICE_BLOCKED" do
      :gun.close(conn_pid)
      {:error, Error.device_blocked()}
    else
      run_connected(conn_pid, stream_ref, room_id, heartbeat_ms, stale_ms, callback)
    end
  end

  defp run_connected(conn_pid, stream_ref, room_id, heartbeat_ms, stale_ms, callback) do
    Logger.info("websocket connected")

    :gun.ws_send(conn_pid, stream_ref, {:binary, Frames.build_heartbeat(room_id)})
    :gun.ws_send(conn_pid, stream_ref, {:binary, Frames.build_enter_room(room_id)})

    _hb_ref = Process.send_after(self(), :heartbeat, heartbeat_ms)
    stale_ref = Process.send_after(self(), :stale_timeout, stale_ms)

    result = ws_loop(conn_pid, stream_ref, room_id, heartbeat_ms, stale_ms, stale_ref, callback)
    :gun.close(conn_pid)
    result
  end

  defp ws_loop(conn_pid, stream_ref, room_id, heartbeat_ms, stale_ms, stale_ref, callback) do
    receive do
      {:gun_ws, ^conn_pid, ^stream_ref, {:binary, data}} ->
        Process.cancel_timer(stale_ref)
        new_stale_ref = Process.send_after(self(), :stale_timeout, stale_ms)

        process_binary(data, conn_pid, stream_ref, callback)
        ws_loop(conn_pid, stream_ref, room_id, heartbeat_ms, stale_ms, new_stale_ref, callback)

      {:gun_ws, ^conn_pid, ^stream_ref, {:close, _, _}} ->
        Logger.info("server sent close frame")
        {:ok, :normal}

      {:gun_ws, ^conn_pid, ^stream_ref, :close} ->
        Logger.info("server sent close frame")
        {:ok, :normal}

      {:gun_down, ^conn_pid, _protocol, reason, _killed} ->
        Logger.error("gun connection down: #{inspect(reason)}")
        {:error, Error.connection_closed()}

      :heartbeat ->
        :gun.ws_send(conn_pid, stream_ref, {:binary, Frames.build_heartbeat(room_id)})
        _hb_ref = Process.send_after(self(), :heartbeat, heartbeat_ms)
        ws_loop(conn_pid, stream_ref, room_id, heartbeat_ms, stale_ms, stale_ref, callback)

      :stale_timeout ->
        Logger.info("stale: no data for #{stale_ms}ms, closing")
        {:ok, :normal}
    end
  end

  defp process_binary(data, conn_pid, stream_ref, callback) do
    handle_push_frame(data, fn bin -> :gun.ws_send(conn_pid, stream_ref, {:binary, bin}) end, callback)
  end

  @doc false
  # Decode one WSS binary message: acks via `send` when TikTok asks, events via `callback`.
  @spec handle_push_frame(binary(), (binary() -> any()), (atom(), any() -> any())) :: any()
  def handle_push_frame(data, send, callback) do
    case safe_decode(WebcastPushFrame, data) do
      {:ok, frame} ->
        handle_frame(frame, send, callback)

      {:error, reason} ->
        Logger.warning("frame decode error: #{inspect(reason)}")
    end
  end

  defp handle_frame(%{payload_type: "msg", payload: payload, log_id: log_id}, send, callback) do
    case Frames.decompress_if_gzipped(payload) do
      {:ok, decompressed} ->
        case safe_decode(WebcastResponse, decompressed) do
          {:ok, response} ->
            if response.needs_ack and response.internal_ext != "" do
              send.(Frames.build_ack(log_id, response.internal_ext))
            end

            Enum.each(response.messages, fn msg ->
              events = Mapper.decode(msg.type, msg.payload)
              Enum.each(events, fn {type, data} -> callback.(type, data) end)
            end)

          {:error, reason} ->
            Logger.warning("response decode error: #{inspect(reason)}")
        end

      {:error, reason} ->
        Logger.warning("gzip decompress error: #{inspect(reason)}")
    end
  end

  defp handle_frame(%{payload_type: "im_enter_room_resp"}, _send, _cb) do
    Logger.info("room entry confirmed")
  end

  defp handle_frame(%{payload_type: "hb"}, _send, _cb), do: :ok

  defp handle_frame(%{payload_type: other}, _send, _cb) do
    Logger.debug("unhandled payload type: #{other}")
  end

  defp safe_decode(mod, data) do
    try do
      {:ok, mod.decode(data)}
    rescue
      e -> {:error, e}
    end
  end

  defp ws_headers(host, cookies, user_agent, language, region) do
    accept_lang = "#{language}-#{region},#{language};q=0.9"

    [
      {"host", host},
      {"user-agent", user_agent},
      {"referer", "https://www.tiktok.com/"},
      {"origin", "https://www.tiktok.com"},
      {"accept-language", accept_lang},
      {"accept-encoding", "gzip, deflate"},
      {"cache-control", "no-cache"},
      {"cookie", cookies}
    ]
  end

  defp header_value(headers, name) do
    case List.keyfind(headers, name, 0) do
      {_, value} -> value
      nil -> "?"
    end
  end
end
