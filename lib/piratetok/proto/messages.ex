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

  field :id, 5, type: :int64
  field :combo, 10, type: :bool
  field :gift_type, 11, type: :int32
  field :name, 16, type: :string
  field :diamond_count, 12, type: :int32
  field :image, 1, type: PirateTok.Live.Proto.Image
end

defmodule PirateTok.Live.Proto.WebcastGiftMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
  field :gift_id, 2, type: :int64
  field :user, 7, type: PirateTok.Live.Proto.UserIdentity
  field :repeat_count, 8, type: :int32
  field :repeat_end, 9, type: :int32
  field :group_id, 11, type: :int64
  field :gift_details, 15, type: PirateTok.Live.Proto.GiftDetails
  field :diamond_count, 16, type: :int32
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
  field :share_target, 3, type: :string
  field :action, 4, type: :int32
  field :share_count, 9, type: :int32
end

defmodule PirateTok.Live.Proto.WebcastRoomUserSeqMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
  field :total_user, 3, type: :int64
  field :popularity, 5, type: :int64
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
  field :intro_text, 2, type: :string
end

defmodule PirateTok.Live.Proto.WebcastRoomMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
  field :content, 2, type: :string
end

defmodule PirateTok.Live.Proto.WebcastCaptionMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :common, 1, type: PirateTok.Live.Proto.CommonMessageData
  field :caption_data, 2, type: :string
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
