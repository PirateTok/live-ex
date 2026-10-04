defmodule PirateTok.Live.Auth.Ttwid do
  @moduledoc false

  alias PirateTok.Live.Error
  alias PirateTok.Live.Http.Client

  @tiktok_url "https://www.tiktok.com/"

  # TikTok sets ttwid on an anonymous GET only intermittently: a response
  # without the cookie is retried this many times, this far apart.
  @fetch_attempts 8
  @retry_delay_ms 750

  @doc """
  Single ttwid request. Missing cookie → `:invalid_response`.
  Opts: `:user_agent`, `:timeout`, `:proxy`, `:url` (default tiktok.com).
  """
  @spec fetch(keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def fetch(opts \\ []) do
    {url, opts} = Keyword.pop(opts, :url, @tiktok_url)

    case Client.get(url, Keyword.merge(opts, no_redirect: true)) do
      {:ok, _status, headers, _body} ->
        case from_headers(headers) do
          nil -> {:error, Error.invalid_response("no ttwid cookie in tiktok.com response")}
          ttwid -> {:ok, ttwid}
        end

      {:error, _} = err ->
        err
    end
  end

  @doc """
  ttwid fetch with bounded retry while the cookie is missing. Transport errors
  return immediately. Extra opts: `:attempts` (8), `:retry_delay` ms (750).
  """
  @spec fetch_retrying(keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def fetch_retrying(opts \\ []) do
    {attempts, opts} = Keyword.pop(opts, :attempts, @fetch_attempts)
    {delay, opts} = Keyword.pop(opts, :retry_delay, @retry_delay_ms)
    retry(opts, 1, attempts, delay)
  end

  defp retry(opts, attempt, attempts, delay) do
    case fetch(opts) do
      {:error, %Error{type: :invalid_response}} when attempt < attempts ->
        Process.sleep(delay)
        retry(opts, attempt + 1, attempts, delay)

      result ->
        result
    end
  end

  @spec from_headers([{String.t(), String.t()}]) :: String.t() | nil
  def from_headers(headers) do
    headers
    |> Enum.filter(fn {k, _} -> String.downcase(k) == "set-cookie" end)
    |> Enum.find_value(fn {_, v} -> extract_ttwid(v) end)
  end

  defp extract_ttwid(set_cookie) do
    [kv | _] = String.split(set_cookie, ";", parts: 2)

    case String.split(kv, "=", parts: 2) do
      ["ttwid", value] when value != "" -> value
      _ -> nil
    end
  end
end
