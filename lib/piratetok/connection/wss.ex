defmodule PirateTok.Live.Connection.Wss do
  @moduledoc false
  # Single WSS connection using :gun. Connects once, streams events to caller,
  # returns on close/stale/error. The client wraps this in a retry loop.

  require Logger

  alias PirateTok.Live.Connection.Frames
  alias PirateTok.Live.Error
  alias PirateTok.Live.Events.Mapper
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

    tls_opts = [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)],
      server_name_indication: host
    ]

    conn_result = open_connection(proxy, host, port, tls_opts)

    case conn_result do
      {:ok, conn_pid} ->
        headers = ws_headers(uri.host, cookies, user_agent, language, region)
        stream_ref = :gun.ws_upgrade(conn_pid, path, headers)
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
            {:ok, conn_pid}

          {:error, reason} ->
            :gun.close(conn_pid)
            {:error, Error.http_error("gun await_up failed: #{inspect(reason)}")}
        end

      {:error, reason} ->
        {:error, Error.http_error("gun open failed: #{inspect(reason)}")}
    end
  end

  defp open_connection(proxy_url, host, port, tls_opts) do
    proxy_uri = URI.parse(proxy_url)
    proxy_host = String.to_charlist(proxy_uri.host || "localhost")
    proxy_port = proxy_uri.port || 8080

    # Open a TCP connection to the proxy (no TLS to proxy itself)
    gun_opts = %{protocols: [:http], transport: :tcp}

    case :gun.open(proxy_host, proxy_port, gun_opts) do
      {:ok, conn_pid} ->
        case :gun.await_up(conn_pid, 10_000) do
          {:ok, _protocol} ->
            # Send CONNECT request to tunnel TLS through the proxy
            connect_dest = %{host: host, port: port, protocols: [:http], transport: :tls, tls_opts: tls_opts}
            stream_ref = :gun.connect(conn_pid, connect_dest)

            case :gun.await(conn_pid, stream_ref, 10_000) do
              {:response, :fin, 200, _headers} ->
                {:ok, conn_pid}

              {:response, :nofin, 200, _headers} ->
                {:ok, conn_pid}

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
    case safe_decode(WebcastPushFrame, data) do
      {:ok, frame} ->
        handle_frame(frame, conn_pid, stream_ref, callback)

      {:error, reason} ->
        Logger.warning("frame decode error: #{inspect(reason)}")
    end
  end

  defp handle_frame(%{payload_type: "msg", payload: payload, log_id: log_id}, conn_pid, stream_ref, callback) do
    case Frames.decompress_if_gzipped(payload) do
      {:ok, decompressed} ->
        case safe_decode(WebcastResponse, decompressed) do
          {:ok, response} ->
            if response.needs_ack and response.internal_ext != "" do
              ack = Frames.build_ack(log_id, response.internal_ext)
              :gun.ws_send(conn_pid, stream_ref, {:binary, ack})
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

  defp handle_frame(%{payload_type: "im_enter_room_resp"}, _cp, _sr, _cb) do
    Logger.info("room entry confirmed")
  end

  defp handle_frame(%{payload_type: "hb"}, _cp, _sr, _cb), do: :ok

  defp handle_frame(%{payload_type: other}, _cp, _sr, _cb) do
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
