defmodule PirateTok.ReplayTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias PirateTok.Live.Connection.Frames, as: ConnFrames
  alias PirateTok.Live.Events.Mapper
  alias PirateTok.Live.Helpers.{GiftStreakTracker, LikeAccumulator}
  alias PirateTok.Live.Proto.{WebcastGiftMessage, WebcastLikeMessage, WebcastPushFrame, WebcastResponse}

  # Canonical event type names matching the Rust golden standard.
  @event_names %{
    chat: "Chat",
    gift: "Gift",
    like: "Like",
    member: "Member",
    social: "Social",
    follow: "Follow",
    share: "Share",
    join: "Join",
    room_user_seq: "RoomUserSeq",
    control: "Control",
    live_ended: "LiveEnded",
    live_intro: "LiveIntro",
    room_message: "RoomMessage",
    caption: "Caption",
    goal_update: "GoalUpdate",
    im_delete: "ImDelete",
    rank_update: "RankUpdate",
    poll: "Poll",
    envelope: "Envelope",
    room_pin: "RoomPin",
    unauthorized_member: "UnauthorizedMember",
    link_mic_method: "LinkMicMethod",
    link_mic_battle: "LinkMicBattle",
    link_mic_armies: "LinkMicArmies",
    link_message: "LinkMessage",
    link_layer: "LinkLayer",
    link_mic_layout_state: "LinkMicLayoutState",
    gift_panel_update: "GiftPanelUpdate",
    in_room_banner: "InRoomBanner",
    guide: "Guide",
    emote_chat: "EmoteChat",
    question_new: "QuestionNew",
    sub_notify: "SubNotify",
    barrage: "Barrage",
    hourly_rank: "HourlyRank",
    msg_detect: "MsgDetect",
    link_mic_fan_ticket: "LinkMicFanTicket",
    room_verify: "RoomVerify",
    oec_live_shopping: "OecLiveShopping",
    gift_broadcast: "GiftBroadcast",
    rank_text: "RankText",
    gift_dynamic_restriction: "GiftDynamicRestriction",
    viewer_picks_update: "ViewerPicksUpdate",
    system_message: "SystemMessage",
    live_game_intro: "LiveGameIntro",
    access_control: "AccessControl",
    access_recall: "AccessRecall",
    alert_box_audit_result: "AlertBoxAuditResult",
    binding_gift: "BindingGift",
    boost_card: "BoostCard",
    bottom_message: "BottomMessage",
    game_rank_notify: "GameRankNotify",
    gift_prompt: "GiftPrompt",
    link_state: "LinkState",
    link_mic_battle_punish_finish: "LinkMicBattlePunishFinish",
    linkmic_battle_task: "LinkmicBattleTask",
    marquee_announcement: "MarqueeAnnouncement",
    notice: "Notice",
    notify: "Notify",
    partnership_drops_update: "PartnershipDropsUpdate",
    partnership_game_offline: "PartnershipGameOffline",
    partnership_punish: "PartnershipPunish",
    perception: "Perception",
    speaker: "Speaker",
    sub_capsule: "SubCapsule",
    sub_pin_event: "SubPinEvent",
    subscription_notify: "SubscriptionNotify",
    toast: "Toast",
    unknown: "Unknown"
  }

  # --- testdata location ---

  defp find_paths(name) do
    candidates =
      [
        {System.get_env("PIRATETOK_TESTDATA"), "captures/#{name}.bin", "manifests/#{name}.json"},
        {"testdata", "captures/#{name}.bin", "manifests/#{name}.json"}
      ]

    Enum.find_value(candidates, :skip, fn
      {nil, _, _} ->
        nil

      {base, cap_rel, man_rel} ->
        cap = Path.join(base, cap_rel)
        man = Path.join(base, man_rel)

        if File.exists?(cap) and File.exists?(man) do
          {cap, man}
        end
    end)
  end

  # --- binary capture reader ---

  defp read_capture(path) do
    data = File.read!(path)
    parse_frames(data, 0, [])
  end

  defp parse_frames(data, pos, acc) when byte_size(data) - pos < 4, do: Enum.reverse(acc)

  defp parse_frames(data, pos, acc) do
    <<_skip::binary-size(pos), len_bytes::binary-size(4), _rest::binary>> = data
    <<len::little-unsigned-32>> = len_bytes
    frame_start = pos + 4

    if frame_start + len > byte_size(data) do
      raise "truncated frame at offset #{pos}"
    end

    <<_skip2::binary-size(frame_start), frame::binary-size(len), _rest2::binary>> = data
    parse_frames(data, frame_start + len, [frame | acc])
  end

  # --- replay engine ---

  defp replay(frames) do
    state = %{
      frame_count: length(frames),
      message_count: 0,
      event_count: 0,
      decode_failures: 0,
      decompress_failures: 0,
      payload_types: %{},
      message_types: %{},
      event_types: %{},
      follow_count: 0,
      share_count: 0,
      join_count: 0,
      live_ended_count: 0,
      unknown_types: %{},
      like_events: [],
      like_acc: LikeAccumulator.new(),
      gift_groups: %{},
      gift_tracker: GiftStreakTracker.new(),
      combo_count: 0,
      non_combo_count: 0,
      streak_finals: 0,
      negative_deltas: 0
    }

    result = Enum.reduce(frames, state, &process_frame/2)
    %{result | like_events: Enum.reverse(result.like_events)}
  end

  defp process_frame(raw, state) do
    case safe_decode(WebcastPushFrame, raw) do
      {:ok, frame} ->
        state = update_in(state.payload_types, &inc_map(&1, frame.payload_type))
        process_payload(frame, state)

      {:error, _} ->
        %{state | decode_failures: state.decode_failures + 1}
    end
  end

  defp process_payload(%{payload_type: "msg", payload: payload}, state) do
    case ConnFrames.decompress_if_gzipped(payload) do
      {:ok, decompressed} ->
        case safe_decode(WebcastResponse, decompressed) do
          {:ok, response} ->
            Enum.reduce(response.messages, state, &process_message/2)

          {:error, _} ->
            %{state | decode_failures: state.decode_failures + 1}
        end

      {:error, _} ->
        %{state | decompress_failures: state.decompress_failures + 1}
    end
  end

  defp process_payload(_frame, state), do: state

  defp process_message(msg, state) do
    state = %{state | message_count: state.message_count + 1}
    state = update_in(state.message_types, &inc_map(&1, msg.type))

    events = Mapper.decode(msg.type, msg.payload)

    state =
      Enum.reduce(events, state, fn {atom, event_data}, st ->
        name = Map.get(@event_names, atom, "Unknown")
        st = %{st | event_count: st.event_count + 1}
        st = update_in(st.event_types, &inc_map(&1, name))

        st =
          case atom do
            :follow -> %{st | follow_count: st.follow_count + 1}
            :share -> %{st | share_count: st.share_count + 1}
            :join -> %{st | join_count: st.join_count + 1}
            :live_ended -> %{st | live_ended_count: st.live_ended_count + 1}
            :unknown -> update_in(st.unknown_types, &inc_map(&1, event_data.method))
            _ -> st
          end

        st
      end)

    state = maybe_process_like(msg, state)
    maybe_process_gift(msg, state)
  end

  defp maybe_process_like(%{type: "WebcastLikeMessage", payload: payload}, state) do
    case safe_decode(WebcastLikeMessage, payload) do
      {:ok, like_msg} ->
        {stats, new_acc} = LikeAccumulator.process(state.like_acc, like_msg)

        entry = %{
          wire_count: like_msg.like_count,
          wire_total: like_msg.total_like_count,
          acc_total: stats.total_like_count,
          accumulated: stats.accumulated_count,
          went_backwards: stats.went_backwards
        }

        %{state | like_acc: new_acc, like_events: [entry | state.like_events]}

      {:error, _} ->
        state
    end
  end

  defp maybe_process_like(_msg, state), do: state

  defp maybe_process_gift(%{type: "WebcastGiftMessage", payload: payload}, state) do
    case safe_decode(WebcastGiftMessage, payload) do
      {:ok, gift_msg} ->
        gift_details = gift_msg.gift_details || %{}
        gift_type = Map.get(gift_details, :gift_type, 0) || 0
        is_combo = gift_type == 1

        state =
          if is_combo do
            %{state | combo_count: state.combo_count + 1}
          else
            %{state | non_combo_count: state.non_combo_count + 1}
          end

        {enriched, new_tracker} = GiftStreakTracker.process(state.gift_tracker, gift_msg)

        state = %{state | gift_tracker: new_tracker}
        state = if enriched.is_final, do: %{state | streak_finals: state.streak_finals + 1}, else: state

        state =
          if enriched.event_gift_count < 0,
            do: %{state | negative_deltas: state.negative_deltas + 1},
            else: state

        group_key = to_string(gift_msg.group_id)

        entry = %{
          gift_id: gift_msg.gift_id,
          repeat_count: gift_msg.repeat_count,
          delta: enriched.event_gift_count,
          is_final: enriched.is_final,
          diamond_total: enriched.total_diamond_count
        }

        update_in(state.gift_groups, fn groups ->
          Map.update(groups, group_key, [entry], &(&1 ++ [entry]))
        end)

      {:error, _} ->
        state
    end
  end

  defp maybe_process_gift(_msg, state), do: state

  defp safe_decode(mod, data) do
    {:ok, mod.decode(data)}
  rescue
    e -> {:error, e}
  end

  defp inc_map(map, key), do: Map.update(map, key, 1, &(&1 + 1))

  # --- manifest loading ---

  defp load_manifest(path) do
    path |> File.read!() |> Jason.decode!()
  end

  # --- assertions ---

  defp assert_replay(name, result, manifest) do
    assert result.frame_count == manifest["frame_count"], "#{name}: frame_count"
    assert result.message_count == manifest["message_count"], "#{name}: message_count"
    assert result.event_count == manifest["event_count"], "#{name}: event_count"
    assert result.decode_failures == manifest["decode_failures"], "#{name}: decode_failures"
    assert result.decompress_failures == manifest["decompress_failures"], "#{name}: decompress_failures"

    assert result.payload_types == manifest["payload_types"], "#{name}: payload_types"
    assert result.message_types == manifest["message_types"], "#{name}: message_types"
    assert result.event_types == manifest["event_types"], "#{name}: event_types"

    sub = manifest["sub_routed"]
    assert result.follow_count == sub["follow"], "#{name}: sub_routed.follow"
    assert result.share_count == sub["share"], "#{name}: sub_routed.share"
    assert result.join_count == sub["join"], "#{name}: sub_routed.join"
    assert result.live_ended_count == sub["live_ended"], "#{name}: sub_routed.live_ended"

    assert result.unknown_types == manifest["unknown_types"], "#{name}: unknown_types"

    assert_like_accumulator(name, result, manifest["like_accumulator"])
    assert_gift_streaks(name, result, manifest["gift_streaks"])
  end

  defp assert_like_accumulator(name, result, ml) do
    like_events = result.like_events
    assert length(like_events) == ml["event_count"], "#{name}: like event_count"

    backwards = Enum.count(like_events, & &1.went_backwards)
    assert backwards == ml["backwards_jumps"], "#{name}: like backwards_jumps"

    if length(like_events) > 0 do
      last = List.last(like_events)
      assert last.acc_total == ml["final_max_total"], "#{name}: like final_max_total"
      assert last.accumulated == ml["final_accumulated"], "#{name}: like final_accumulated"
    end

    acc_mono = monotonic?(like_events, :acc_total)
    accum_mono = monotonic?(like_events, :accumulated)
    assert acc_mono == ml["acc_total_monotonic"], "#{name}: like acc_total_monotonic"
    assert accum_mono == ml["accumulated_monotonic"], "#{name}: like accumulated_monotonic"

    # event-by-event
    expected_events = ml["events"]
    assert length(like_events) == length(expected_events), "#{name}: like events length"

    like_events
    |> Enum.zip(expected_events)
    |> Enum.with_index()
    |> Enum.each(fn {{got, expected}, i} ->
      assert got.wire_count == expected["wire_count"], "#{name}: like[#{i}].wire_count"
      assert got.wire_total == expected["wire_total"], "#{name}: like[#{i}].wire_total"
      assert got.acc_total == expected["acc_total"], "#{name}: like[#{i}].acc_total"
      assert got.accumulated == expected["accumulated"], "#{name}: like[#{i}].accumulated"
      assert got.went_backwards == expected["went_backwards"], "#{name}: like[#{i}].went_backwards"
    end)
  end

  defp assert_gift_streaks(name, result, mg) do
    total = result.combo_count + result.non_combo_count
    assert total == mg["event_count"], "#{name}: gift event_count"
    assert result.combo_count == mg["combo_count"], "#{name}: gift combo_count"
    assert result.non_combo_count == mg["non_combo_count"], "#{name}: gift non_combo_count"
    assert result.streak_finals == mg["streak_finals"], "#{name}: gift streak_finals"
    assert result.negative_deltas == mg["negative_deltas"], "#{name}: gift negative_deltas"

    expected_groups = mg["groups"]
    assert map_size(result.gift_groups) == map_size(expected_groups), "#{name}: gift groups count"

    Enum.each(result.gift_groups, fn {gid, got_events} ->
      expected_events = Map.fetch!(expected_groups, gid)
      assert length(got_events) == length(expected_events), "#{name}: gift group #{gid} length"

      got_events
      |> Enum.zip(expected_events)
      |> Enum.with_index()
      |> Enum.each(fn {{got, expected}, i} ->
        assert got.gift_id == expected["gift_id"], "#{name}: gift[#{gid}][#{i}].gift_id"
        assert got.repeat_count == expected["repeat_count"], "#{name}: gift[#{gid}][#{i}].repeat_count"
        assert got.delta == expected["delta"], "#{name}: gift[#{gid}][#{i}].delta"
        assert got.is_final == expected["is_final"], "#{name}: gift[#{gid}][#{i}].is_final"
        assert got.diamond_total == expected["diamond_total"], "#{name}: gift[#{gid}][#{i}].diamond_total"
      end)
    end)
  end

  defp monotonic?(events, _field) when length(events) < 2, do: true

  defp monotonic?(events, field) do
    events
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [a, b] -> Map.get(b, field) >= Map.get(a, field) end)
  end

  # --- test runner ---

  defp run_capture_test(name) do
    case find_paths(name) do
      :skip ->
        IO.puts("SKIP #{name}: no testdata (set PIRATETOK_TESTDATA or clone live-testdata)")

      {cap_path, man_path} ->
        manifest = load_manifest(man_path)
        frames = read_capture(cap_path)
        result = replay(frames)
        assert_replay(name, result, manifest)
    end
  end

  test "replay calvinterest6" do
    run_capture_test("calvinterest6")
  end

  test "replay happyhappygaltv" do
    run_capture_test("happyhappygaltv")
  end

  test "replay fox4newsdallasfortworth" do
    run_capture_test("fox4newsdallasfortworth")
  end
end
