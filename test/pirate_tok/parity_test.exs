defmodule PirateTok.ParityTest do
  # Offline tests: ttwid retry against a local fake HTTP responder, reconnect
  # policy + client loop, ranks_list/top_viewers, audience + anchor_id parsing.
  use ExUnit.Case, async: true

  alias PirateTok.Live.Auth.Ttwid
  alias PirateTok.Live.Client
  alias PirateTok.Live.Connection.{Reconnect, Url}
  alias PirateTok.Live.Error
  alias PirateTok.Live.Events.Mapper
  alias PirateTok.Live.Http.{Api, Audience}
  alias PirateTok.Live.Proto

  # --- fake HTTP responder ---

  # Serves `responses` (:no_cookie | :cookie) in order, repeating the last one,
  # and reports each request to the test process.
  defp fake_server(responses) do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)
    test_pid = self()
    spawn_link(fn -> serve(listen, responses, test_pid) end)
    "http://127.0.0.1:#{port}/"
  end

  defp serve(listen, responses, test_pid) do
    {:ok, sock} = :gen_tcp.accept(listen)
    {:ok, _req} = :gen_tcp.recv(sock, 0, 5_000)
    send(test_pid, :ttwid_request)
    [current | rest] = responses
    cookie = if current == :cookie, do: "Set-Cookie: ttwid=1%7Cfake%7C123; Path=/; Secure\r\n", else: ""

    :ok =
      :gen_tcp.send(
        sock,
        "HTTP/1.1 200 OK\r\nSet-Cookie: msToken=x; Path=/\r\n#{cookie}Content-Length: 2\r\nConnection: close\r\n\r\nok"
      )

    :gen_tcp.close(sock)
    serve(listen, if(rest == [], do: [current], else: rest), test_pid)
  end

  defp count_requests(acc \\ 0) do
    receive do
      :ttwid_request -> count_requests(acc + 1)
    after
      0 -> acc
    end
  end

  # --- W1: ttwid retry ---

  test "ttwid: missing cookie x3 then cookie -> ok on 4th request" do
    url = fake_server([:no_cookie, :no_cookie, :no_cookie, :cookie])
    assert {:ok, "1%7Cfake%7C123"} = Ttwid.fetch_retrying(url: url, retry_delay: 1, timeout: 2_000)
    assert count_requests() == 4
  end

  test "ttwid: never a cookie -> invalid_response after 8 requests" do
    url = fake_server([:no_cookie])
    assert {:error, %Error{type: :invalid_response}} = Ttwid.fetch_retrying(url: url, retry_delay: 1, timeout: 2_000)
    assert count_requests() == 8
  end

  test "ttwid: transport error propagates without retry" do
    {:ok, listen} = :gen_tcp.listen(0, [])
    {:ok, port} = :inet.port(listen)
    :gen_tcp.close(listen)
    started = System.monotonic_time(:millisecond)

    assert {:error, %Error{type: :http_error}} =
             Ttwid.fetch_retrying(url: "http://127.0.0.1:#{port}/", retry_delay: 500, timeout: 2_000)

    assert System.monotonic_time(:millisecond) - started < 500, "no retry sleep on transport error"
  end

  # --- W1: reconnect policy ---

  test "policy: consecutive failures accumulate with backoff, then give up" do
    assert {:retry, 1, 2_000, false} = Reconnect.decide(0, :failed, 3)
    assert {:retry, 2, 4_000, false} = Reconnect.decide(1, :failed, 3)
    assert {:retry, 3, 8_000, false} = Reconnect.decide(2, :failed, 3)
    assert :give_up = Reconnect.decide(3, :failed, 3)
  end

  test "policy: healthy resets counter and keeps session; blocked rotates with 2s" do
    assert {:retry, 1, 2_000, true} = Reconnect.decide(4, :healthy, 5)
    assert {:retry, 3, 2_000, false} = Reconnect.decide(2, :blocked, 5)
    assert Reconnect.decide(30, :failed, 40) == {:retry, 31, 30_000, false}
  end

  test "policy: classify by result and session length" do
    assert Reconnect.classify({:error, Error.device_blocked()}, 60_000) == :blocked
    assert Reconnect.classify(:ok, 30_000) == :healthy
    assert Reconnect.classify({:error, Error.connection_closed()}, 45_000) == :healthy
    assert Reconnect.classify(:ok, 5_000) == :failed
  end

  # --- W1: client loop (GenServer callbacks driven directly) ---

  defp client_state(fields) do
    struct!(%Client{username: "someone", room_id: "7000000000000000000", caller: self(), max_retries: 5}, fields)
  end

  defp finished_task_state(fields) do
    ref = make_ref()
    {ref, client_state([ws_task: %Task{ref: ref, pid: self(), owner: self(), mfa: {Kernel, :apply, 2}}] ++ fields)}
  end

  test "loop: ttwid failure on connect is a failed attempt, not an abort" do
    url = fake_server([:no_cookie])
    state = client_state(ttwid_opts: [url: url, retry_delay: 1, attempts: 2])

    assert {:noreply, next} = Client.handle_info(:connect_ws, state)
    assert next.attempt == 1
    assert next.session == nil
    assert_received {:tiktok_live, :reconnecting, %{attempt: 1, delay_secs: 2}}
    assert count_requests() == 2
  end

  test "loop: healthy session resets attempt and keeps ttwid + UA" do
    started = System.monotonic_time(:millisecond) - 31_000
    {ref, state} = finished_task_state(attempt: 4, session: {"held", "UA/1"}, attempt_started_at: started)

    assert {:noreply, next} = Client.handle_info({ref, :ok}, state)
    assert next.attempt == 1
    assert next.session == {"held", "UA/1"}
    assert_received {:tiktok_live, :reconnecting, %{attempt: 1, delay_secs: 2, device_blocked: false}}
  end

  test "loop: short-lived session counts as failure and rotates" do
    started = System.monotonic_time(:millisecond) - 5_000
    {ref, state} = finished_task_state(attempt: 1, session: {"held", "UA/1"}, attempt_started_at: started)

    assert {:noreply, next} = Client.handle_info({ref, {:error, Error.connection_closed()}}, state)
    assert next.attempt == 2
    assert next.session == nil
  end

  test "loop: DEVICE_BLOCKED rotates with 2s delay even after a long session" do
    started = System.monotonic_time(:millisecond) - 60_000
    {ref, state} = finished_task_state(attempt: 0, session: {"held", "UA/1"}, attempt_started_at: started)

    assert {:noreply, next} = Client.handle_info({ref, {:error, Error.device_blocked()}}, state)
    assert next.session == nil
    assert_received {:tiktok_live, :reconnecting, %{attempt: 1, delay_secs: 2, device_blocked: true}}
  end

  test "loop: max_retries exceeded -> disconnected + stop" do
    {ref, state} = finished_task_state(attempt: 5, attempt_started_at: System.monotonic_time(:millisecond))

    assert {:stop, :normal, _} = Client.handle_info({ref, {:error, Error.connection_closed()}}, state)
    assert_received {:tiktok_live, :disconnected, nil}
  end

  test "url: heartbeat_duration follows heartbeat_interval" do
    url = Url.build("webcast-ws.tiktok.com", "1", "UTC", "en", "US", true, 7_000)
    assert url =~ "heartbeat_duration=7000"
  end

  # --- W4: ranks_list + top_viewers ---

  test "ranks_list decodes; top_viewers skips userless and sorts by rank" do
    contributor = fn rank, score, user ->
      %Proto.Contributor{rank: rank, score: score, delta: 0, user: user}
    end

    payload =
      Proto.WebcastRoomUserSeqMessage.encode(%Proto.WebcastRoomUserSeqMessage{
        ranks_list: [
          contributor.(3, 300, %Proto.UserIdentity{user_id: 33, nickname: "c"}),
          contributor.(1, 900, %Proto.UserIdentity{user_id: 11, nickname: "a"}),
          contributor.(4, 50, nil),
          contributor.(2, 600, %Proto.UserIdentity{user_id: 22, nickname: "b"})
        ],
        viewer_count: 1234,
        pop_str: "1.2K",
        total_user: 5678,
        anonymous: 9
      })

    assert [{:room_user_seq, seq}] = Mapper.decode("WebcastRoomUserSeqMessage", payload)
    assert length(seq.ranks_list) == 4
    assert {seq.viewer_count, seq.total_user, seq.pop_str, seq.anonymous} == {1234, 5678, "1.2K", 9}
    assert Enum.map(PirateTok.Live.top_viewers(seq), & &1.user.nickname) == ["a", "b", "c"]
    assert hd(PirateTok.Live.top_viewers(seq)).score == 900
  end

  # --- W5: online_audience parsing ---

  test "audience: status 0 parses viewers and skips rank without user" do
    body =
      Jason.encode!(%{
        status_code: 0,
        data: %{
          total: 42,
          anonymous: 7,
          ranks: [
            %{
              rank: 1,
              score: 500,
              user: %{
                id_str: "7200000000000000001",
                display_id: "viewer_one",
                nickname: "One",
                sec_uid: "MS4w",
                avatar_thumb: %{url_list: ["https://p16/a.jpg"]},
                follow_info: %{follower_count: 99},
                verified: true,
                is_follower: true,
                is_following: false,
                is_subscribe: true
              }
            },
            %{rank: 2, score: 100}
          ]
        }
      })

    assert {:ok, %Audience{total: 42, anonymous: 7, viewers: [v], raw_json: ^body}} = Audience.parse(body, 200)
    assert v.user_id == "7200000000000000001"
    assert {v.username, v.nickname, v.sec_uid} == {"viewer_one", "One", "MS4w"}
    assert v.avatar_url == "https://p16/a.jpg"
    assert v.follower_count == 99
    assert {v.verified, v.is_follower, v.is_following, v.is_subscriber} == {true, true, false, true}
  end

  test "audience: 20003 -> session_required" do
    assert {:error, %Error{type: :session_required, message: msg}} =
             Audience.parse(Jason.encode!(%{status_code: 20_003, data: %{}}), 200)

    assert msg =~ "session cookies"
  end

  test "audience: other code -> invalid_response with code and message" do
    assert {:error, %Error{type: :invalid_response, message: msg}} =
             Audience.parse(Jason.encode!(%{status_code: 10_011, data: %{message: "param error"}}), 200)

    assert msg =~ "online_audience status_code=10011 param error"
  end

  test "audience: empty body / missing status_code -> invalid_response" do
    assert {:error, %Error{type: :invalid_response, message: m1}} = Audience.parse("", 502)
    assert m1 =~ "http 502"
    assert {:error, %Error{type: :invalid_response}} = Audience.parse(Jason.encode!(%{data: %{}}), 200)
  end

  test "audience: owner id from room info" do
    assert {:ok, "6800000000000000009"} =
             Audience.owner_id(Jason.encode!(%{data: %{owner: %{id_str: "6800000000000000009"}}}))

    assert {:error, %Error{message: "invalid response: no owner id in room info"}} =
             Audience.owner_id(Jason.encode!(%{data: %{}}))
  end

  # --- W3: anchor_id ---

  test "check_online: anchor_id = data.user.id" do
    body =
      Jason.encode!(%{
        statusCode: 0,
        data: %{user: %{id: "6900000000000000001", roomId: "7300000000000000002", status: 2}, liveRoom: %{status: 2}}
      })

    assert {:ok, %{room_id: "7300000000000000002", anchor_id: "6900000000000000001"}} =
             Api.parse_room_id_response(200, body, "someone")
  end

  test "check_online: error mapping" do
    assert {:error, %Error{type: :user_not_found}} =
             Api.parse_room_id_response(200, Jason.encode!(%{statusCode: 19_881_007}), "x")

    assert {:error, %Error{type: :host_not_online}} =
             Api.parse_room_id_response(200, Jason.encode!(%{statusCode: 0, data: %{user: %{id: "1", roomId: "0"}}}), "x")

    assert {:error, %Error{type: :api_error, message: msg}} =
             Api.parse_room_id_response(200, Jason.encode!(%{statusCode: 10_101}), "x")

    assert msg =~ "10101"
    assert {:error, %Error{type: :tiktok_blocked}} = Api.parse_room_id_response(429, "{}", "x")
    assert {:error, %Error{type: :tiktok_blocked}} = Api.parse_room_id_response(200, "", "x")
    assert {:error, %Error{type: :tiktok_blocked}} = Api.parse_room_id_response(200, "<html>captcha</html>", "x")
  end

  # --- F15: gift helpers ---

  test "gift helpers: combo, streak over, diamond total" do
    combo = %Proto.WebcastGiftMessage{gift_details: %Proto.GiftDetails{gift_type: 1, diamond_count: 5}, repeat_count: 3}
    plain = %Proto.WebcastGiftMessage{gift_details: %Proto.GiftDetails{gift_type: 2, diamond_count: 100}, repeat_count: 0}

    assert PirateTok.Live.is_combo_gift(combo)
    refute PirateTok.Live.is_combo_gift(plain)
    refute PirateTok.Live.is_streak_over(combo)
    assert PirateTok.Live.is_streak_over(%{combo | repeat_end: 1})
    assert PirateTok.Live.is_streak_over(plain)
    assert PirateTok.Live.diamond_total(combo) == 15
    assert PirateTok.Live.diamond_total(plain) == 100
  end
end
