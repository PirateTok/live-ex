defmodule PirateTok.WireTest do
  # Offline wire tests (F2/F6/F7/F8/F9): the real client runs through a local HTTP CONNECT
  # proxy (Basic auth required) that terminates TLS with a generated CA/cert and fakes
  # www.tiktok.com (room id + ttwid) and webcast-ws (WebSocket upgrade, records frames).
  use ExUnit.Case, async: false

  require Record

  alias PirateTok.Live.Auth.Ttwid
  alias PirateTok.Live.Connection.{Frames, Wss}
  alias PirateTok.Live.Http.Api
  alias PirateTok.Live.Proto

  Record.defrecordp(:extension, :Extension, Record.extract(:Extension, from_lib: "public_key/include/public_key.hrl"))

  @auth "Basic " <> Base.encode64("user:p@ss")
  @room ~s({"statusCode":0,"data":{"user":{"id":"690001","roomId":"730002","status":2},"liveRoom":{"status":2}}})

  setup_all do
    hosts = [~c"www.tiktok.com", ~c"webcast-ws.eu.tiktok.com", ~c"webcast-ws.tiktok.com"]
    san = extension(extnID: {2, 5, 29, 17}, critical: false, extnValue: Enum.map(hosts, &{:dNSName, &1}))

    data =
      :public_key.pkix_test_data(%{
        server_chain: %{root: [key: {:rsa, 2048, 65_537}], intermediates: [], peer: [key: {:rsa, 2048, 65_537}, extensions: [san]]},
        client_chain: %{root: [key: {:rsa, 2048, 65_537}], intermediates: [], peer: [key: {:rsa, 2048, 65_537}]}
      })

    %{server_opts: data.server_config, cacerts: Keyword.fetch!(data.client_config, :cacerts)}
  end

  # ---- fake proxy + TLS fake ----

  defp start_proxy(server_opts) do
    {:ok, ls} = :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(ls)
    test_pid = self()
    spawn_link(fn -> accept_loop(ls, server_opts, test_pid) end)
    port
  end

  defp accept_loop(ls, server_opts, test_pid) do
    {:ok, s} = :gen_tcp.accept(ls)
    pid = spawn(fn -> handle_proxy(s, server_opts, test_pid) end)
    :ok = :gen_tcp.controlling_process(s, pid)
    accept_loop(ls, server_opts, test_pid)
  end

  defp handle_proxy(s, server_opts, test_pid) do
    {head, _rest} = recv_head(:gen_tcp, s, "")
    send(test_pid, {:proxy, head})

    if String.starts_with?(head, "CONNECT ") and header(head, "proxy-authorization") == @auth do
      :ok = :gen_tcp.send(s, "HTTP/1.1 200 Connection Established\r\n\r\n")
      {:ok, tls} = :ssl.handshake(s, server_opts ++ [active: false], 5_000)
      {inner, rest} = recv_head(:ssl, tls, "")
      send(test_pid, {:server, inner})

      if String.downcase(header(inner, "upgrade") || "") == "websocket" do
        accept = Base.encode64(:crypto.hash(:sha, header(inner, "sec-websocket-key") <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
        :ok = :ssl.send(tls, "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: #{accept}\r\n\r\n")
        read_frames(tls, rest, test_pid)
      else
        {body, cookie} =
          cond do
            String.starts_with?(inner, "GET /api-live/user/room") -> {@room, ""}
            String.starts_with?(inner, "GET / ") -> {"ok", "Set-Cookie: ttwid=1%7Cwire%7C9; Path=/; Secure\r\n"}
            true -> {"ok", ""}
          end

        :ssl.send(tls, "HTTP/1.1 200 OK\r\n#{cookie}Content-Type: application/json\r\nContent-Length: #{byte_size(body)}\r\nConnection: close\r\n\r\n#{body}")
      end

      :ssl.close(tls)
    else
      :gen_tcp.send(s, "HTTP/1.1 407 Proxy Authentication Required\r\nProxy-Authenticate: Basic realm=\"t\"\r\nContent-Length: 0\r\n\r\n")
      :gen_tcp.close(s)
    end
  end

  defp recv_head(mod, sock, buf) do
    case :binary.split(buf, "\r\n\r\n") do
      [head, rest] ->
        {head, rest}

      [_] ->
        {:ok, more} = mod.recv(sock, 0, 5_000)
        recv_head(mod, sock, buf <> more)
    end
  end

  defp header(head, name) do
    head
    |> String.split("\r\n")
    |> Enum.find_value(fn line ->
      case String.split(line, ":", parts: 2) do
        [k, v] -> if String.downcase(k) == name, do: String.trim(v)
        _ -> nil
      end
    end)
  end

  defp read_frames(tls, buf, test_pid) do
    case parse_frame(buf) do
      {:ok, 8, _payload, _rest} ->
        :ok

      {:ok, _op, payload, rest} ->
        send(test_pid, {:frame, payload})
        read_frames(tls, rest, test_pid)

      :more ->
        case :ssl.recv(tls, 0, 5_000) do
          {:ok, more} -> read_frames(tls, buf <> more, test_pid)
          {:error, _closed} -> :ok
        end
    end
  end

  defp parse_frame(<<_fin::1, _rsv::3, op::4, 1::1, len::7, rest::binary>>) when len < 126, do: unmask(op, len, rest)
  defp parse_frame(<<_fin::1, _rsv::3, op::4, 1::1, 126::7, len::16, rest::binary>>), do: unmask(op, len, rest)
  defp parse_frame(_buf), do: :more

  defp unmask(op, len, buf) when byte_size(buf) >= len + 4 do
    <<mask::binary-size(4), payload::binary-size(^len), rest::binary>> = buf
    key = :binary.bin_to_list(mask)
    data = payload |> :binary.bin_to_list() |> Enum.with_index() |> Enum.map(fn {b, i} -> Bitwise.bxor(b, Enum.at(key, rem(i, 4))) end)
    {:ok, op, :binary.list_to_bin(data), rest}
  end

  defp unmask(_op, _len, _short), do: :more

  defp drain(tag, acc \\ []) do
    receive do
      {^tag, v} -> drain(tag, [v | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp first_line(head), do: head |> String.split("\r\n") |> hd()

  # ---- tests ----

  test "proxy: ttwid GET tunnels via authenticated CONNECT www.tiktok.com:443", ctx do
    port = start_proxy(ctx.server_opts)
    proxy = "http://user:p%40ss@127.0.0.1:#{port}"

    assert {:ok, "1%7Cwire%7C9"} = Ttwid.fetch(user_agent: "UA-Test/1", proxy: proxy, tls_cacerts: ctx.cacerts)
    assert_receive {:server, get}, 2_000
    connects = drain(:proxy) |> Enum.filter(&(header(&1, "proxy-authorization") == @auth))
    assert Enum.any?(connects, &(first_line(&1) == "CONNECT www.tiktok.com:443 HTTP/1.1"))
    assert first_line(get) == "GET / HTTP/1.1"
    assert header(get, "user-agent") == "UA-Test/1"
  end

  test "connect: room id + ttwid + WSS through the proxy; UA/cookies/locale/compress on the wire", ctx do
    port = start_proxy(ctx.server_opts)
    proxy = "http://user:p%40ss@127.0.0.1:#{port}"

    {:ok, pid} =
      PirateTok.Live.Client.start_link("someone",
        proxy: proxy,
        user_agent: "UA-Test/1",
        cookies: "sessionid=abc; sid_tt=def",
        language: "ro",
        region: "RO",
        compress: false,
        heartbeat_interval: 7_000,
        cdn: :eu,
        tls_cacerts: ctx.cacerts
      )

    assert_receive {:tiktok_live, :connected, %{room_id: "730002"}}, 5_000
    assert_receive {:frame, hb_raw}, 5_000
    assert_receive {:frame, enter_raw}, 5_000
    GenServer.stop(pid)

    targets = drain(:proxy) |> Enum.filter(&(header(&1, "proxy-authorization") == @auth)) |> Enum.map(&first_line/1)
    assert "CONNECT www.tiktok.com:443 HTTP/1.1" in targets
    assert "CONNECT webcast-ws.eu.tiktok.com:443 HTTP/1.1" in targets

    heads = drain(:server)
    room = Enum.find(heads, &String.starts_with?(&1, "GET /api-live/user/room"))
    assert room =~ "app_language=ro&browser_language=ro-RO&region=RO"
    assert header(room, "user-agent") == "UA-Test/1"

    up = Enum.find(heads, &(String.downcase(header(&1, "upgrade") || "") == "websocket"))
    line = first_line(up)
    for q <- ["room_id=730002", "browser_language=ro-RO", "app_language=ro", "webcast_language=ro", "compress=&", "heartbeat_duration=7000"] do
      assert line =~ q, "upgrade URL has #{q}"
    end

    assert header(up, "host") == "webcast-ws.eu.tiktok.com"
    assert header(up, "cookie") == "ttwid=1%7Cwire%7C9; sessionid=abc; sid_tt=def"
    assert header(up, "user-agent") == "UA-Test/1"
    assert header(up, "accept-language") == "ro-RO,ro;q=0.9"

    hb = Proto.WebcastPushFrame.decode(hb_raw)
    assert hb.payload_type == "hb"
    assert Proto.HeartbeatMessage.decode(hb.payload).room_id == 730_002
    enter = Proto.WebcastPushFrame.decode(enter_raw)
    assert enter.payload_type == "im_enter_room"
  end

  test "proxy: wrong credentials -> WSS dial fails at CONNECT (407)", ctx do
    port = start_proxy(ctx.server_opts)

    assert {:error, %{message: msg}} =
             Wss.connect("wss://webcast-ws.tiktok.com/x?y=1", "ttwid=x", "UA", "1",
               callback: fn _, _ -> :ok end,
               proxy: "http://user:nope@127.0.0.1:#{port}",
               tls_cacerts: ctx.cacerts
             )

    assert msg =~ "407"
  end

  test "proxy: socks5 rejected explicitly (HTTP CONNECT only)" do
    assert {:error, %{type: :invalid_url}} = Ttwid.fetch(proxy: "socks5://127.0.0.1:1080")
  end

  # ---- F2: ack ----

  test "push frame: needs_ack sends ack with log_id + exact internal_ext" do
    # internal_ext is proto `string` (UTF-8 enforced, as in live-rs); TikTok sends ASCII like this
    ext = "internal_src:dim|wss_push_room_id:730002|wss_push_did:7|first_req_ms:1759600000000"
    resp = Proto.WebcastResponse.encode(%Proto.WebcastResponse{needs_ack: true, internal_ext: ext})
    raw = Proto.WebcastPushFrame.encode(%Proto.WebcastPushFrame{log_id: 42, payload_type: "msg", payload: resp})
    test_pid = self()
    Wss.handle_push_frame(raw, fn bin -> send(test_pid, {:sent, bin}) end, fn _, _ -> :ok end)
    assert_received {:sent, ack_raw}
    ack = Proto.WebcastPushFrame.decode(ack_raw)
    assert ack.payload_type == "ack"
    assert ack.log_id == 42
    assert ack.payload == ext
    assert ack_raw == Frames.build_ack(42, ext)
  end

  # ---- F9: room info parsing ----

  test "room info: fields, FLV (uhd fallback), AgeRestricted" do
    sd = Jason.encode!(%{data: %{origin: %{main: %{flv: "o.flv"}}, uhd: %{main: %{flv: "u.flv"}}, sd: %{main: %{flv: "s.flv"}}}})

    body =
      Jason.encode!(%{
        status_code: 0,
        data: %{title: "T", user_count: 5, stats: %{like_count: 6, total_user: 7}, stream_url: %{live_core_sdk_data: %{pull_data: %{stream_data: sd}}}}
      })

    assert {:ok, info} = Api.parse_room_info(body)
    assert {info.title, info.viewers, info.likes, info.total_viewers} == {"T", 5, 6, 7}
    assert info.stream_url.flv_origin == "o.flv"
    assert info.stream_url.flv_hd == "u.flv"
    assert info.stream_url.flv_sd == "s.flv"
    assert info.stream_url.flv_ld == nil
    assert info.raw_json == body
    assert {:error, %{type: :age_restricted}} = Api.parse_room_info(~s({"status_code":4003110}))
  end
end
