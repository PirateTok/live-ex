defmodule PirateTok.Live.Http.Audience do
  @moduledoc """
  Parsing for the `online_audience` endpoint — the full named viewer roster
  behind the web viewer panel. Pure functions over the response body.
  """

  alias PirateTok.Live.Error

  defmodule Viewer do
    @moduledoc "One named viewer from the audience roster."
    defstruct [
      :rank,
      :score,
      :user_id,
      :username,
      :nickname,
      :sec_uid,
      :avatar_url,
      :follower_count,
      :verified,
      :is_follower,
      :is_following,
      :is_subscriber
    ]

    @type t :: %__MODULE__{}
  end

  defstruct [:total, :anonymous, :viewers, :raw_json]

  @type t :: %__MODULE__{
          total: integer(),
          anonymous: integer(),
          viewers: [Viewer.t()],
          raw_json: String.t()
        }

  @session_required 20_003

  @spec parse(binary(), integer()) :: {:ok, t()} | {:error, Error.t()}
  def parse("", status), do: {:error, Error.invalid_response("empty response from online_audience (http #{status})")}

  def parse(body, _status) do
    case Jason.decode(body) do
      {:ok, %{} = json} -> from_json(json, body)
      _ -> {:error, Error.invalid_response("online_audience JSON parse failed")}
    end
  end

  defp from_json(%{"status_code" => 0} = json, body) do
    case json["data"] do
      %{} = data ->
        viewers =
          case data["ranks"] do
            ranks when is_list(ranks) -> Enum.flat_map(ranks, &viewer/1)
            _ -> []
          end

        {:ok, %__MODULE__{total: int(data["total"]), anonymous: int(data["anonymous"]), viewers: viewers, raw_json: body}}

      _ ->
        {:error, Error.invalid_response("missing 'data' in online_audience")}
    end
  end

  defp from_json(%{"status_code" => @session_required}, _body) do
    {:error,
     Error.session_required(
       "audience roster needs login — pass session cookies (sessionid=xxx; sid_tt=xxx) to fetch_room_audience()"
     )}
  end

  defp from_json(%{"status_code" => code} = json, _body) when is_integer(code) do
    msg = get_in(json, ["data", "message"])
    msg = if is_binary(msg), do: msg, else: ""
    {:error, Error.invalid_response("online_audience status_code=#{code} #{msg}")}
  end

  defp from_json(_json, _body), do: {:error, Error.invalid_response("no status_code in online_audience response")}

  defp viewer(%{"user" => %{} = user} = rank) do
    [
      %Viewer{
        rank: int(rank["rank"]),
        score: int(rank["score"]),
        user_id: user_id(user),
        username: str(user["display_id"]),
        nickname: str(user["nickname"]),
        sec_uid: str(user["sec_uid"]),
        avatar_url: avatar(user),
        follower_count: int(get_in(user, ["follow_info", "follower_count"])),
        verified: user["verified"] == true,
        is_follower: user["is_follower"] == true,
        is_following: user["is_following"] == true,
        is_subscriber: user["is_subscribe"] == true
      }
    ]
  end

  defp viewer(_rank), do: []

  defp user_id(%{"id_str" => id}) when is_binary(id) and id != "", do: id
  defp user_id(%{"id" => id}) when is_integer(id), do: Integer.to_string(id)
  defp user_id(_user), do: "0"

  defp avatar(%{"avatar_thumb" => %{"url_list" => [url | _]}}) when is_binary(url), do: url
  defp avatar(_user), do: nil

  defp int(v) when is_integer(v), do: v
  defp int(_), do: 0

  defp str(v) when is_binary(v), do: v
  defp str(_), do: ""

  @doc "Streamer id (`data.owner.id_str`) from a room/info body."
  @spec owner_id(binary()) :: {:ok, String.t()} | {:error, Error.t()}
  def owner_id(raw_json) do
    case Jason.decode(raw_json) do
      {:ok, %{"data" => %{"owner" => %{"id_str" => id}}}} when is_binary(id) and id != "" -> {:ok, id}
      _ -> {:error, Error.invalid_response("no owner id in room info")}
    end
  end
end
