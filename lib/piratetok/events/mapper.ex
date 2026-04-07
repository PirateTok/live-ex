defmodule PirateTok.Live.Events.Mapper do
  @moduledoc false

  alias PirateTok.Live.Proto

  # Maps wire message type string to {event_atom, proto_module}
  @known_types %{
    # core events
    "WebcastChatMessage" => {:chat, Proto.WebcastChatMessage},
    "WebcastGiftMessage" => {:gift, Proto.WebcastGiftMessage},
    "WebcastLikeMessage" => {:like, Proto.WebcastLikeMessage},
    "WebcastRoomUserSeqMessage" => {:room_user_seq, Proto.WebcastRoomUserSeqMessage},
    # useful events
    "WebcastLiveIntroMessage" => {:live_intro, Proto.WebcastLiveIntroMessage},
    "WebcastRoomMessage" => {:room_message, Proto.WebcastRoomMessage},
    "WebcastCaptionMessage" => {:caption, Proto.WebcastCaptionMessage},
    "WebcastGoalUpdateMessage" => {:goal_update, Proto.WebcastGoalUpdateMessage},
    "WebcastImDeleteMessage" => {:im_delete, Proto.WebcastImDeleteMessage},
    # niche events
    "WebcastRankUpdateMessage" => {:rank_update, Proto.WebcastRankUpdateMessage},
    "WebcastPollMessage" => {:poll, Proto.WebcastPollMessage},
    "WebcastEnvelopeMessage" => {:envelope, Proto.WebcastEnvelopeMessage},
    "WebcastRoomPinMessage" => {:room_pin, Proto.WebcastRoomPinMessage},
    "WebcastUnauthorizedMemberMessage" => {:unauthorized_member, Proto.WebcastUnauthorizedMemberMessage},
    "WebcastLinkMicMethod" => {:link_mic_method, Proto.WebcastLinkMicMethod},
    "WebcastLinkMicBattle" => {:link_mic_battle, Proto.WebcastLinkMicBattle},
    "WebcastLinkMicArmies" => {:link_mic_armies, Proto.WebcastLinkMicArmies},
    "WebcastLinkMessage" => {:link_message, Proto.WebcastLinkMessage},
    "WebcastLinkLayerMessage" => {:link_layer, Proto.WebcastLinkLayerMessage},
    "WebcastLinkMicLayoutStateMessage" => {:link_mic_layout_state, Proto.WebcastLinkMicLayoutStateMessage},
    "WebcastGiftPanelUpdateMessage" => {:gift_panel_update, Proto.WebcastGiftPanelUpdateMessage},
    "WebcastInRoomBannerMessage" => {:in_room_banner, Proto.WebcastInRoomBannerMessage},
    "WebcastGuideMessage" => {:guide, Proto.WebcastGuideMessage},
    # extended events
    "WebcastEmoteChatMessage" => {:emote_chat, Proto.WebcastEmoteChatMessage},
    "WebcastQuestionNewMessage" => {:question_new, Proto.WebcastQuestionNewMessage},
    "WebcastSubNotifyMessage" => {:sub_notify, Proto.WebcastSubNotifyMessage},
    "WebcastBarrageMessage" => {:barrage, Proto.WebcastBarrageMessage},
    "WebcastHourlyRankMessage" => {:hourly_rank, Proto.WebcastHourlyRankMessage},
    "WebcastMsgDetectMessage" => {:msg_detect, Proto.WebcastMsgDetectMessage},
    "WebcastLinkMicFanTicketMethod" => {:link_mic_fan_ticket, Proto.WebcastLinkMicFanTicketMethod},
    "WebcastRoomVerifyMessage" => {:room_verify, Proto.WebcastRoomVerifyMessage},
    "RoomVerifyMessage" => {:room_verify, Proto.WebcastRoomVerifyMessage},
    "WebcastOecLiveShoppingMessage" => {:oec_live_shopping, Proto.WebcastOecLiveShoppingMessage},
    "WebcastGiftBroadcastMessage" => {:gift_broadcast, Proto.WebcastGiftBroadcastMessage},
    "WebcastRankTextMessage" => {:rank_text, Proto.WebcastRankTextMessage},
    "WebcastGiftDynamicRestrictionMessage" => {:gift_dynamic_restriction, Proto.WebcastGiftDynamicRestrictionMessage},
    "WebcastViewerPicksUpdateMessage" => {:viewer_picks_update, Proto.WebcastViewerPicksUpdateMessage},
    # secondary events
    "WebcastSystemMessage" => {:system_message, Proto.WebcastSystemMessage},
    "WebcastLiveGameIntroMessage" => {:live_game_intro, Proto.WebcastLiveGameIntroMessage},
    "WebcastAccessControlMessage" => {:access_control, Proto.WebcastAccessControlMessage},
    "WebcastAccessRecallMessage" => {:access_recall, Proto.WebcastAccessRecallMessage},
    "WebcastAlertBoxAuditResultMessage" => {:alert_box_audit_result, Proto.WebcastAlertBoxAuditResultMessage},
    "WebcastBindingGiftMessage" => {:binding_gift, Proto.WebcastBindingGiftMessage},
    "WebcastBoostCardMessage" => {:boost_card, Proto.WebcastBoostCardMessage},
    "WebcastBottomMessage" => {:bottom_message, Proto.WebcastBottomMessage},
    "WebcastGameRankNotifyMessage" => {:game_rank_notify, Proto.WebcastGameRankNotifyMessage},
    "WebcastGiftPromptMessage" => {:gift_prompt, Proto.WebcastGiftPromptMessage},
    "WebcastLinkStateMessage" => {:link_state, Proto.WebcastLinkStateMessage},
    "WebcastLinkMicBattlePunishFinish" => {:link_mic_battle_punish_finish, Proto.WebcastLinkMicBattlePunishFinish},
    "WebcastLinkmicBattleTaskMessage" => {:linkmic_battle_task, Proto.WebcastLinkmicBattleTaskMessage},
    "WebcastMarqueeAnnouncementMessage" => {:marquee_announcement, Proto.WebcastMarqueeAnnouncementMessage},
    "WebcastNoticeMessage" => {:notice, Proto.WebcastNoticeMessage},
    "WebcastNotifyMessage" => {:notify, Proto.WebcastNotifyMessage},
    "WebcastPartnershipDropsUpdateMessage" => {:partnership_drops_update, Proto.WebcastPartnershipDropsUpdateMessage},
    "WebcastPartnershipGameOfflineMessage" => {:partnership_game_offline, Proto.WebcastPartnershipGameOfflineMessage},
    "WebcastPartnershipPunishMessage" => {:partnership_punish, Proto.WebcastPartnershipPunishMessage},
    "WebcastPerceptionMessage" => {:perception, Proto.WebcastPerceptionMessage},
    "WebcastSpeakerMessage" => {:speaker, Proto.WebcastSpeakerMessage},
    "WebcastSubCapsuleMessage" => {:sub_capsule, Proto.WebcastSubCapsuleMessage},
    "WebcastSubPinEventMessage" => {:sub_pin_event, Proto.WebcastSubPinEventMessage},
    "WebcastSubscriptionNotifyMessage" => {:subscription_notify, Proto.WebcastSubscriptionNotifyMessage},
    "WebcastToastMessage" => {:toast, Proto.WebcastToastMessage}
  }

  @spec decode(String.t(), binary()) :: [{atom(), map() | binary()}]
  def decode(msg_type, payload) do
    cond do
      msg_type == "WebcastSocialMessage" -> decode_social(payload)
      msg_type == "WebcastMemberMessage" -> decode_member(payload)
      msg_type == "WebcastControlMessage" -> decode_control(payload)
      Map.has_key?(@known_types, msg_type) -> decode_simple(msg_type, payload)
      true -> [{:unknown, %{method: msg_type, payload: payload}}]
    end
  end

  defp decode_simple(msg_type, payload) do
    {event_atom, proto_mod} = Map.fetch!(@known_types, msg_type)

    try do
      [{event_atom, proto_mod.decode(payload)}]
    rescue
      _ -> [{:unknown, %{method: msg_type, payload: payload}}]
    end
  end

  defp decode_social(payload) do
    try do
      msg = Proto.WebcastSocialMessage.decode(payload)

      convenience =
        case msg.action do
          1 -> [{:follow, msg}]
          a when a in [2, 3, 4, 5] -> [{:share, msg}]
          _ -> []
        end

      [{:social, msg} | convenience]
    rescue
      _ -> [{:unknown, %{method: "WebcastSocialMessage", payload: payload}}]
    end
  end

  defp decode_member(payload) do
    try do
      msg = Proto.WebcastMemberMessage.decode(payload)
      convenience = if msg.action == 1, do: [{:join, msg}], else: []
      [{:member, msg} | convenience]
    rescue
      _ -> [{:unknown, %{method: "WebcastMemberMessage", payload: payload}}]
    end
  end

  defp decode_control(payload) do
    try do
      msg = Proto.WebcastControlMessage.decode(payload)
      convenience = if msg.action == 3, do: [{:live_ended, msg}], else: []
      [{:control, msg} | convenience]
    rescue
      _ -> [{:unknown, %{method: "WebcastControlMessage", payload: payload}}]
    end
  end
end
