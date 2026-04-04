defmodule PirateTok.Live.Proto.CommonMessageData do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :method, 1, type: :string
  field :msg_id, 2, type: :int64
  field :room_id, 3, type: :int64
  field :create_time, 4, type: :int64
  field :log_id, 12, type: :string
end

defmodule PirateTok.Live.Proto.Image do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :url_list, 1, repeated: true, type: :string
end

defmodule PirateTok.Live.Proto.FollowInfo do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :following_count, 1, type: :int64
  field :follower_count, 2, type: :int64
  field :follow_status, 3, type: :int64
end

defmodule PirateTok.Live.Proto.PrivilegeLogExtra do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :data_version, 1, type: :string
  field :privilege_id, 2, type: :string
  field :level, 5, type: :string
end

defmodule PirateTok.Live.Proto.BadgeImage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :image, 2, type: PirateTok.Live.Proto.Image
end

defmodule PirateTok.Live.Proto.BadgeText do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :key, 2, type: :string
  field :default_pattern, 3, type: :string
end

defmodule PirateTok.Live.Proto.BadgeString do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :content_str, 2, type: :string
end

defmodule PirateTok.Live.Proto.BadgeStruct do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :display_type, 1, type: :int32
  field :badge_scene, 3, type: :int32
  field :display, 11, type: :bool
  field :log_extra, 12, type: PirateTok.Live.Proto.PrivilegeLogExtra
  field :image_badge, 20, type: PirateTok.Live.Proto.BadgeImage
  field :text_badge, 21, type: PirateTok.Live.Proto.BadgeText
  field :string_badge, 22, type: PirateTok.Live.Proto.BadgeString
end

defmodule PirateTok.Live.Proto.FansClubData do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :club_name, 1, type: :string
  field :level, 2, type: :int32
end

defmodule PirateTok.Live.Proto.FansClubMember do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :data, 1, type: PirateTok.Live.Proto.FansClubData
end

defmodule PirateTok.Live.Proto.UserIdentity do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :user_id, 1, type: :int64
  field :nickname, 3, type: :string
  field :bio_description, 5, type: :string
  field :avatar_thumb, 9, type: PirateTok.Live.Proto.Image
  field :avatar_medium, 10, type: PirateTok.Live.Proto.Image
  field :avatar_large, 11, type: PirateTok.Live.Proto.Image
  field :verified, 12, type: :bool
  field :follow_info, 22, type: PirateTok.Live.Proto.FollowInfo
  field :fans_club, 24, type: PirateTok.Live.Proto.FansClubMember
  field :top_vip_no, 31, type: :int32
  field :pay_score, 34, type: :int64
  field :fan_ticket_count, 35, type: :int64
  field :unique_id, 38, type: :string
  field :display_id, 46, type: :string
  field :badge_list, 64, repeated: true, type: PirateTok.Live.Proto.BadgeStruct
  field :follow_status, 1024, type: :int64
  field :is_follower, 1029, type: :bool
  field :is_following, 1030, type: :bool
  field :is_subscribe, 1090, type: :bool
end

defmodule PirateTok.Live.Proto.UserIdentityContext do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :is_gift_giver_of_anchor, 1, type: :bool
  field :is_subscriber_of_anchor, 2, type: :bool
  field :is_mutual_following_with_anchor, 3, type: :bool
  field :is_follower_of_anchor, 4, type: :bool
  field :is_moderator_of_anchor, 5, type: :bool
  field :is_anchor, 6, type: :bool
end
