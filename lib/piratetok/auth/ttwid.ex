defmodule PirateTok.Live.Auth.Ttwid do
  @moduledoc false

  alias PirateTok.Live.Error
  alias PirateTok.Live.Http.Client

  @tiktok_url "https://www.tiktok.com/"

  @spec fetch(keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def fetch(opts \\ []) do
    case Client.get(@tiktok_url, Keyword.merge(opts, no_redirect: true)) do
      {:ok, _status, headers, _body} ->
        headers
        |> Enum.filter(fn {k, _} -> String.downcase(k) == "set-cookie" end)
        |> Enum.find_value(fn {_, v} -> extract_ttwid(v) end)
        |> case do
          nil -> {:error, Error.invalid_response("no ttwid cookie in tiktok.com response")}
          ttwid -> {:ok, ttwid}
        end

      {:error, _} = err ->
        err
    end
  end

  defp extract_ttwid(set_cookie) do
    case String.split(set_cookie, ";", parts: 2) do
      [kv | _] ->
        case String.split(kv, "=", parts: 2) do
          ["ttwid", value] when value != "" -> value
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
