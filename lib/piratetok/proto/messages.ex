defmodule PirateTok.Live.Proto.WebcastChatMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
  field :user, 2, type: PirateTok.Live.Proto.UserIdentity
  field :comment, 3, type: :string
  field :content_language, 14, type: :string
  field :user_identity, 18, type: PirateTok.Live.Proto.UserIdentityContext
end

defmodule PirateTok.Live.Proto.GiftDetails do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :image, 1, type: PirateTok.Live.Proto.Image
  field :id, 5, type: :int64
  field :combo, 10, type: :bool
  field :gift_type, 11, type: :int32
  field :diamond_count, 12, type: :int32
  field :gift_name, 16, type: :string
end

defmodule PirateTok.Live.Proto.WebcastGiftMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
  field :gift_id, 2, type: :int32
  field :fan_ticket_count, 3, type: :int64
  field :group_count, 4, type: :int32
  field :repeat_count, 5, type: :int32
  field :combo_count, 6, type: :int32
  field :user, 7, type: PirateTok.Live.Proto.UserIdentity
  field :to_user, 8, type: PirateTok.Live.Proto.UserIdentity
  field :repeat_end, 9, type: :int32
  field :group_id, 11, type: :uint64
  field :gift_details, 15, type: PirateTok.Live.Proto.GiftDetails
  field :is_first_sent, 25, type: :bool
  field :user_identity, 32, type: PirateTok.Live.Proto.UserIdentityContext
end

defmodule PirateTok.Live.Proto.WebcastLikeMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
  field :like_count, 2, type: :int32
  field :total_like_count, 3, type: :int32
  field :user, 5, type: PirateTok.Live.Proto.UserIdentity
end

defmodule PirateTok.Live.Proto.WebcastMemberMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
  field :user, 2, type: PirateTok.Live.Proto.UserIdentity
  field :member_count, 3, type: :int32
  field :action, 10, type: :int32
end

defmodule PirateTok.Live.Proto.WebcastSocialMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
  field :user, 2, type: PirateTok.Live.Proto.UserIdentity
  field :share_type, 3, type: :int64
  field :action, 4, type: :int64
  field :share_target, 5, type: :string
  field :follow_count, 6, type: :int32
  field :share_display_style, 7, type: :int64
  field :share_count, 8, type: :int32
end

defmodule PirateTok.Live.Proto.WebcastRoomUserSeqMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
  field :viewer_count, 3, type: :int32
  field :popularity, 6, type: :int64
  field :total_user, 7, type: :int32
end

defmodule PirateTok.Live.Proto.WebcastControlMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
  field :action, 2, type: :int32
end

defmodule PirateTok.Live.Proto.WebcastLiveIntroMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
  field :room_id, 2, type: :int64
  field :audit_status, 3, type: :int32
  field :content, 4, type: :string
end

defmodule PirateTok.Live.Proto.WebcastRoomMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
  field :content, 2, type: :string
end

defmodule PirateTok.Live.Proto.CaptionData do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :language, 1, type: :string
  field :text, 2, type: :string
end

defmodule PirateTok.Live.Proto.WebcastCaptionMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
  field :time_stamp, 2, type: :uint64
  field :caption_data, 4, type: PirateTok.Live.Proto.CaptionData
end

defmodule PirateTok.Live.Proto.WebcastEmoteChatMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
  field :user, 2, type: PirateTok.Live.Proto.UserIdentity
end

defmodule PirateTok.Live.Proto.WebcastGoalUpdateMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastImDeleteMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastRankUpdateMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastPollMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastEnvelopeMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastRoomPinMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastUnauthorizedMemberMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastLinkMicMethod do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastLinkMicBattle do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastLinkMicArmies do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastLinkMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastLinkLayerMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastLinkMicLayoutStateMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastGiftPanelUpdateMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastInRoomBannerMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastGuideMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastQuestionNewMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastSubNotifyMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastBarrageMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastHourlyRankMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastMsgDetectMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastLinkMicFanTicketMethod do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastRoomVerifyMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastOecLiveShoppingMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastGiftBroadcastMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastRankTextMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastGiftDynamicRestrictionMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastViewerPicksUpdateMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastSystemMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastLiveGameIntroMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastAccessControlMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastAccessRecallMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastAlertBoxAuditResultMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastBindingGiftMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastBoostCardMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastBottomMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastGameRankNotifyMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastGiftPromptMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastLinkStateMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastLinkMicBattlePunishFinish do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastLinkmicBattleTaskMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastMarqueeAnnouncementMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastNoticeMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastNotifyMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastPartnershipDropsUpdateMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastPartnershipGameOfflineMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastPartnershipPunishMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastPerceptionMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastSpeakerMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastSubCapsuleMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastSubPinEventMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastSubscriptionNotifyMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end

defmodule PirateTok.Live.Proto.WebcastToastMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
end
