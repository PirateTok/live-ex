defmodule PirateTok.Live.Http.Sigi do
  @moduledoc false

  alias PirateTok.Live.Error
  alias PirateTok.Live.Http.Client

  @sigi_marker ~S(id="__UNIVERSAL_DATA_FOR_REHYDRATION__")

  @type sigi_profile :: %{
          user_id: String.t(),
          unique_id: String.t(),
          nickname: String.t(),
          bio: String.t(),
          avatar_thumb: String.t(),
          avatar_medium: String.t(),
          avatar_large: String.t(),
          verified: boolean(),
          private_account: boolean(),
          is_organization: boolean(),
          room_id: String.t(),
          bio_link: String.t() | nil,
          follower_count: integer(),
          following_count: integer(),
          heart_count: integer(),
          video_count: integer(),
          friend_count: integer()
        }

  @spec scrape_profile(String.t(), String.t(), keyword()) ::
          {:ok, sigi_profile()} | {:error, Error.t()}
  def scrape_profile(username, ttwid, opts \\ []) do
    clean = username |> String.trim() |> String.trim_leading("@") |> String.downcase()
    extra_cookies = Keyword.get(opts, :cookies, "")

    cookie = build_cookie(ttwid, extra_cookies)
    url = "https://www.tiktok.com/@#{clean}"

    merged_opts =
      opts
      |> Keyword.put(:cookies, cookie)
      |> Keyword.put_new(:timeout, 15_000)

    case Client.get(url, merged_opts) do
      {:ok, _status, _headers, body} ->
        parse_sigi(body, clean)

      {:error, _} = err ->
        err
    end
  end

  defp parse_sigi(html, username) do
    with {:ok, json_str} <- extract_sigi_json(html),
         {:ok, blob} <- Jason.decode(json_str) do
      scope = get_in(blob, ["__DEFAULT_SCOPE__"])

      if is_nil(scope) do
        {:error, Error.profile_scrape("missing __DEFAULT_SCOPE__")}
      else
        detail = Map.get(scope, "webapp.user-detail")

        if is_nil(detail) do
          {:error, Error.profile_scrape("missing webapp.user-detail")}
        else
          parse_user_detail(detail, username)
        end
      end
    end
  end

  defp parse_user_detail(detail, username) do
    status_code = Map.get(detail, "statusCode", 0)

    case status_code do
      0 ->
        extract_profile(detail)

      10222 ->
        {:error, Error.profile_private(username)}

      code when code in [10221, 10223] ->
        {:error, Error.profile_not_found(username)}

      code ->
        {:error, Error.profile_error(code)}
    end
  end

  defp extract_profile(detail) do
    user_info = Map.get(detail, "userInfo", %{})
    user = Map.get(user_info, "user", %{})
    stats = Map.get(user_info, "stats", %{})

    if map_size(user) == 0 do
      {:error, Error.profile_scrape("missing userInfo.user")}
    else
      bio_link =
        case get_in(user, ["bioLink", "link"]) do
          s when is_binary(s) and s != "" -> s
          _ -> nil
        end

      {:ok,
       %{
         user_id: to_string(Map.get(user, "id", "")),
         unique_id: Map.get(user, "uniqueId", ""),
         nickname: Map.get(user, "nickname", ""),
         bio: Map.get(user, "signature", ""),
         avatar_thumb: Map.get(user, "avatarThumb", ""),
         avatar_medium: Map.get(user, "avatarMedium", ""),
         avatar_large: Map.get(user, "avatarLarger", ""),
         verified: Map.get(user, "verified", false) == true,
         private_account: Map.get(user, "privateAccount", false) == true,
         is_organization: Map.get(user, "isOrganization", 0) != 0,
         room_id: Map.get(user, "roomId", ""),
         bio_link: bio_link,
         follower_count: Map.get(stats, "followerCount", 0),
         following_count: Map.get(stats, "followingCount", 0),
         heart_count: Map.get(stats, "heartCount", 0),
         video_count: Map.get(stats, "videoCount", 0),
         friend_count: Map.get(stats, "friendCount", 0)
       }}
    end
  end

  defp extract_sigi_json(html) do
    case :binary.match(html, @sigi_marker) do
      :nomatch ->
        {:error, Error.profile_scrape("SIGI script tag not found")}

      {marker_pos, marker_len} ->
        after_marker = binary_part(html, marker_pos + marker_len, byte_size(html) - marker_pos - marker_len)

        case :binary.match(after_marker, ">") do
          :nomatch ->
            {:error, Error.profile_scrape("no > after SIGI marker")}

          {gt_offset, 1} ->
            json_start = marker_pos + marker_len + gt_offset + 1
            rest = binary_part(html, json_start, byte_size(html) - json_start)

            case :binary.match(rest, "</script>") do
              :nomatch ->
                {:error, Error.profile_scrape("no </script> after SIGI JSON")}

              {script_offset, _} ->
                json_str = binary_part(rest, 0, script_offset)

                if json_str == "" do
                  {:error, Error.profile_scrape("empty SIGI JSON blob")}
                else
                  {:ok, json_str}
                end
            end
        end
    end
  end

  defp build_cookie(ttwid, extra) do
    base = "ttwid=#{ttwid}"

    if extra == "" do
      base
    else
      filtered =
        extra
        |> String.split("; ")
        |> Enum.reject(&String.starts_with?(&1, "ttwid="))
        |> Enum.join("; ")

      if filtered == "", do: base, else: "#{base}; #{filtered}"
    end
  end
end
