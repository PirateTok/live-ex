defmodule PirateTok.Live.Http.Client do
  @moduledoc false
  # Minimal HTTPS GET using Erlang's built-in :httpc (no deps for HTTP).

  alias PirateTok.Live.Error
  alias PirateTok.Live.Http.UA

  @spec get(String.t(), keyword()) :: {:ok, integer(), [{String.t(), String.t()}], binary()} | {:error, Error.t()}
  def get(url, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 10_000)
    ua = Keyword.get(opts, :user_agent) || UA.random_ua()
    cookies = Keyword.get(opts, :cookies)
    no_redirect = Keyword.get(opts, :no_redirect, false)

    headers = [
      {~c"User-Agent", String.to_charlist(ua)},
      {~c"Referer", ~c"https://www.tiktok.com/"},
      {~c"Accept-Language", ~c"en-US,en;q=0.9"}
    ]

    headers =
      if cookies && cookies != "" do
        [{~c"Cookie", String.to_charlist(cookies)} | headers]
      else
        headers
      end

    http_opts = [
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
      ],
      timeout: timeout,
      autoredirect: not no_redirect
    ]

    url_charlist = String.to_charlist(url)

    case :httpc.request(:get, {url_charlist, headers}, http_opts, body_format: :binary) do
      {:ok, {{_http_ver, status, _reason}, resp_headers, body}} ->
        resp_headers =
          Enum.map(resp_headers, fn {k, v} ->
            {List.to_string(k), List.to_string(v)}
          end)

        {:ok, status, resp_headers, body}

      {:error, reason} ->
        {:error, Error.http_error("request failed: #{inspect(reason)}")}
    end
  end
end
