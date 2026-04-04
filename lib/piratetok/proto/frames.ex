defmodule PirateTok.Live.Proto.WebcastPushFrame do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :seq_id, 1, type: :int64
  field :log_id, 2, type: :int64
  field :service, 3, type: :int64
  field :method, 4, type: :int64
  field :payload_encoding, 6, type: :string
  field :payload_type, 7, type: :string
  field :payload, 8, type: :bytes
end

defmodule PirateTok.Live.Proto.HeartbeatMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :room_id, 1, type: :uint64
end

defmodule PirateTok.Live.Proto.WebcastImEnterRoomMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :room_id, 1, type: :int64
  field :room_tag, 2, type: :string
  field :live_region, 3, type: :string
  field :live_id, 4, type: :int64
  field :identity, 5, type: :string
  field :cursor, 6, type: :string
  field :account_type, 7, type: :int64
  field :enter_unique_id, 8, type: :int64
  field :filter_welcome_msg, 9, type: :string
  field :is_anchor_continue_keep_msg, 10, type: :bool
end

defmodule PirateTok.Live.Proto.WebcastResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :messages, 1, repeated: true, type: PirateTok.Live.Proto.WebcastMessage
  field :cursor, 2, type: :string
  field :fetch_interval, 3, type: :int64
  field :now, 4, type: :int64
  field :internal_ext, 5, type: :string
  field :fetch_type, 6, type: :int32
  field :heartbeat_duration, 8, type: :int32
  field :needs_ack, 9, type: :bool
  field :push_server, 10, type: :string
  field :is_first, 11, type: :bool
  field :history_comment_cursor, 12, type: :string
  field :history_no_more, 13, type: :bool
end

defmodule PirateTok.Live.Proto.WebcastMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :type, 1, type: :string
  field :payload, 2, type: :bytes
  field :msg_id, 3, type: :int64
  field :msg_type, 4, type: :int32
  field :offset, 5, type: :int64
  field :is_history, 6, type: :bool
end
