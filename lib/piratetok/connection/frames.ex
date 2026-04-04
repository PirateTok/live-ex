defmodule PirateTok.Live.Connection.Frames do
  @moduledoc false

  alias PirateTok.Live.Proto.{HeartbeatMessage, WebcastImEnterRoomMessage, WebcastPushFrame}

  @spec build_heartbeat(String.t()) :: binary()
  def build_heartbeat(room_id) do
    hb_payload = HeartbeatMessage.encode(%HeartbeatMessage{room_id: String.to_integer(room_id)})

    WebcastPushFrame.encode(%WebcastPushFrame{
      payload_encoding: "pb",
      payload_type: "hb",
      payload: hb_payload
    })
  end

  @spec build_enter_room(String.t()) :: binary()
  def build_enter_room(room_id) do
    msg_payload =
      WebcastImEnterRoomMessage.encode(%WebcastImEnterRoomMessage{
        room_id: String.to_integer(room_id),
        live_id: 12,
        identity: "audience",
        filter_welcome_msg: "0"
      })

    WebcastPushFrame.encode(%WebcastPushFrame{
      payload_encoding: "pb",
      payload_type: "im_enter_room",
      payload: msg_payload
    })
  end

  @spec build_ack(integer(), binary()) :: binary()
  def build_ack(log_id, internal_ext) do
    WebcastPushFrame.encode(%WebcastPushFrame{
      log_id: log_id,
      payload_encoding: "pb",
      payload_type: "ack",
      payload: internal_ext
    })
  end

  @spec decompress_if_gzipped(binary()) :: {:ok, binary()} | {:error, term()}
  def decompress_if_gzipped(<<0x1F, 0x8B, _rest::binary>> = data) do
    try do
      {:ok, :zlib.gunzip(data)}
    rescue
      e -> {:error, e}
    end
  end

  def decompress_if_gzipped(data), do: {:ok, data}
end
