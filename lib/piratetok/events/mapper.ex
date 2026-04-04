defmodule PirateTok.Live.Events.Mapper do
  @moduledoc false

  alias PirateTok.Live.Proto

  # Maps wire message type string to {event_atom, proto_module}
  @known_types %{
    "WebcastChatMessage" => {:chat, Proto.WebcastChatMessage},
    "WebcastGiftMessage" => {:gift, Proto.WebcastGiftMessage},
    "WebcastLikeMessage" => {:like, Proto.WebcastLikeMessage},
    "WebcastRoomUserSeqMessage" => {:room_user_seq, Proto.WebcastRoomUserSeqMessage},
    "WebcastLiveIntroMessage" => {:live_intro, Proto.WebcastLiveIntroMessage},
    "WebcastRoomMessage" => {:room_message, Proto.WebcastRoomMessage},
    "WebcastCaptionMessage" => {:caption, Proto.WebcastCaptionMessage},
    "WebcastGoalUpdateMessage" => {:goal_update, Proto.WebcastGoalUpdateMessage},
    "WebcastImDeleteMessage" => {:im_delete, Proto.WebcastImDeleteMessage},
    "WebcastRankUpdateMessage" => {:rank_update, Proto.WebcastRankUpdateMessage},
    "WebcastPollMessage" => {:poll, Proto.WebcastPollMessage},
    "WebcastEnvelopeMessage" => {:envelope, Proto.WebcastEnvelopeMessage},
    "WebcastRoomPinMessage" => {:room_pin, Proto.WebcastRoomPinMessage},
    "WebcastEmoteChatMessage" => {:emote_chat, Proto.WebcastEmoteChatMessage}
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
