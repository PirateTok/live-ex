defmodule PirateTok.Live.Http.Api do
  @moduledoc false

  alias PirateTok.Live.Error
  alias PirateTok.Live.Http.Client
  alias PirateTok.Live.Http.UA

  @tiktok_url "https://www.tiktok.com/"
  @webcast_url "https://webcast.tiktok.com/webcast/"

  @spec check_online(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def check_online(username, opts \\ []) do
    clean = username |> String.trim() |> String.trim_leading("@")

    url =
      "#{@tiktok_url}api-live/user/room?aid=1988&app_name=tiktok_web" <>
        "&device_platform=web_pc&app_language=en&browser_language=en-US" <>
        "&region=RO&user_is_login=false&uniqueId=#{URI.encode(clean)}" <>
        "&sourceType=54&staleTime=600000"

    case Client.get(url, opts) do
      {:ok, _status, _headers, body} ->
        parse_room_id_response(body, clean)

      {:error, _} = err ->
        err
    end
  end

  defp parse_room_id_response(body, username) do
    case Jason.decode(body) do
      {:ok, json} ->
        case json["statusCode"] do
          0 -> extract_room_id(json, username)
          19_881_007 -> {:error, Error.user_not_found(username)}
          code -> {:error, Error.invalid_response("tiktok api statusCode=#{code}")}
        end

      {:error, _} ->
        {:error, Error.invalid_response("JSON parse failed")}
    end
  end

  defp extract_room_id(json, _username) do
    room_id = get_in(json, ["data", "user", "roomId"]) || ""

    if room_id == "" or room_id == "0" do
      {:error, Error.host_not_online("no active room")}
    else
      live_status =
        get_in(json, ["data", "liveRoom", "status"]) ||
          get_in(json, ["data", "user", "status"]) ||
          0

      if live_status == 2 do
        {:ok, room_id}
      else
        {:error, Error.host_not_online("status=#{live_status}")}
      end
    end
  end

  @spec fetch_room_info(String.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def fetch_room_info(room_id, opts \\ []) do
    tz = UA.system_timezone() |> URI.encode()

    url =
      "#{@webcast_url}room/info/?aid=1988&app_name=tiktok_web" <>
        "&device_platform=web_pc&app_language=en&browser_language=en-US" <>
        "&browser_name=Mozilla&browser_online=true&browser_platform=Win32" <>
        "&browser_version=5.0+(Windows+NT+10.0%3B+Win64%3B+x64)" <>
        "&cookie_enabled=true&focus_state=true&from_page=user" <>
        "&screen_height=1080&screen_width=1920" <>
        "&tz_name=#{tz}&webcast_language=en" <>
        "&room_id=#{room_id}"

    case Client.get(url, opts) do
      {:ok, _status, _headers, ""} ->
        {:error, Error.invalid_response("empty response from room/info")}

      {:ok, _status, _headers, body} ->
        parse_room_info(body)

      {:error, _} = err ->
        err
    end
  end

  defp parse_room_info(body) do
    case Jason.decode(body) do
      {:ok, json} ->
        case json["status_code"] do
          4_003_110 ->
            {:error, Error.age_restricted("18+ room — pass session cookies to fetch_room_info()")}

          code when is_integer(code) and code != 0 ->
            {:error, Error.invalid_response("room/info status_code=#{code}")}

          _ ->
            extract_room_info(json, body)
        end

      {:error, _} ->
        {:error, Error.invalid_response("JSON parse failed")}
    end
  end

  defp extract_room_info(json, raw_body) do
    data = json["data"]

    if is_nil(data) do
      {:error, Error.invalid_response("missing 'data' in room info")}
    else
      stats = data["stats"] || %{}

      info = %{
        title: data["title"] || "",
        viewers: data["user_count"] || 0,
        likes: stats["like_count"] || 0,
        total_viewers: stats["total_user"] || 0,
        stream_url: parse_stream_urls(data),
        raw_json: raw_body
      }

      {:ok, info}
    end
  end

  defp parse_stream_urls(data) do
    stream_data_str = get_in(data, ["stream_url", "live_core_sdk_data", "pull_data", "stream_data"])

    case stream_data_str do
      nil ->
        nil

      str when is_binary(str) ->
        case Jason.decode(str) do
          {:ok, nested} ->
            %{
              flv_origin: get_in(nested, ["data", "origin", "main", "flv"]),
              flv_hd: get_in(nested, ["data", "hd", "main", "flv"]) || get_in(nested, ["data", "uhd", "main", "flv"]),
              flv_sd: get_in(nested, ["data", "sd", "main", "flv"]),
              flv_ld: get_in(nested, ["data", "ld", "main", "flv"]),
              flv_ao: get_in(nested, ["data", "ao", "main", "flv"])
            }

          {:error, _} ->
            nil
        end

      _ ->
        nil
    end
  end
end
