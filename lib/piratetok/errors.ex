defmodule PirateTok.Live.Error do
  @moduledoc "Errors from TikTok Live connections."

  defexception [:type, :message]

  @type t :: %__MODULE__{type: atom(), message: String.t()}

  @spec user_not_found(String.t()) :: t()
  def user_not_found(username), do: %__MODULE__{type: :user_not_found, message: "user not found: #{username}"}

  @spec host_not_online(String.t()) :: t()
  def host_not_online(reason), do: %__MODULE__{type: :host_not_online, message: "host not online: #{reason}"}

  @spec age_restricted(String.t()) :: t()
  def age_restricted(msg), do: %__MODULE__{type: :age_restricted, message: "age-restricted stream: #{msg}"}

  @spec device_blocked() :: t()
  def device_blocked, do: %__MODULE__{type: :device_blocked, message: "device blocked — ttwid was flagged, fetch a fresh one"}

  @spec invalid_response(String.t()) :: t()
  def invalid_response(msg), do: %__MODULE__{type: :invalid_response, message: "invalid response: #{msg}"}

  @spec connection_closed() :: t()
  def connection_closed, do: %__MODULE__{type: :connection_closed, message: "connection closed"}

  @spec http_error(String.t()) :: t()
  def http_error(msg), do: %__MODULE__{type: :http_error, message: "http: #{msg}"}
end
