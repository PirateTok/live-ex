defmodule PirateTok.Live.Http.Client do
  @moduledoc false
  # Minimal HTTPS GET using Erlang's built-in :httpc (no deps for HTTP).
  # Proxies: http://[user:pass@]host:port via HTTP CONNECT, one httpc profile per proxy
  # (httpc only takes proxies as profile options). SOCKS is not supported.

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

    http_opts = [ssl: tls_opts(url, opts), timeout: timeout, autoredirect: not no_redirect]

    with {:ok, profile, http_opts} <- proxy_profile(Keyword.get(opts, :proxy), http_opts) do
      case :httpc.request(:get, {String.to_charlist(url), headers}, http_opts, [body_format: :binary], profile) do
        {:ok, {{_http_ver, status, _reason}, resp_headers, body}} ->
          resp_headers = Enum.map(resp_headers, fn {k, v} -> {List.to_string(k), List.to_string(v)} end)
          {:ok, status, resp_headers, body}

        {:error, reason} ->
          {:error, Error.http_error("request failed: #{inspect(reason)}")}
      end
    end
  end

  # verify_peer against the system store; :tls_cacerts (DER list) replaces it — used by
  # the offline wire tests to trust their generated CA.
  @doc false
  @spec tls_opts(String.t(), keyword()) :: keyword()
  def tls_opts(url, opts) do
    [
      verify: :verify_peer,
      cacerts: Keyword.get(opts, :tls_cacerts) || :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(URI.parse(url).host || ""),
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]
  end

  @doc "Parse http://[user:pass@]host:port → {host, port, {user, pass} | nil}."
  @spec parse_proxy(String.t()) :: {:ok, {charlist(), pos_integer(), {String.t(), String.t()} | nil}} | {:error, Error.t()}
  def parse_proxy(proxy) do
    uri = URI.parse(proxy)

    cond do
      uri.scheme not in ["http", "https"] ->
        {:error, Error.invalid_url("unsupported proxy '#{proxy}' — only HTTP CONNECT proxies (http://[user:pass@]host:port)")}

      is_nil(uri.host) or uri.host == "" ->
        {:error, Error.invalid_url("invalid proxy URL: #{proxy}")}

      true ->
        creds =
          case uri.userinfo do
            nil -> nil
            info -> info |> String.split(":", parts: 2) |> Enum.map(&URI.decode/1) |> List.to_tuple() |> pad_creds()
          end

        {:ok, {String.to_charlist(uri.host), uri.port || 8080, creds}}
    end
  end

  defp pad_creds({user}), do: {user, ""}
  defp pad_creds({_user, _pass} = creds), do: creds

  defp proxy_profile(proxy, http_opts) when proxy in [nil, ""], do: {:ok, :default, http_opts}

  defp proxy_profile(proxy, http_opts) do
    with {:ok, {host, port, creds}} <- parse_proxy(proxy) do
      profile = :"piratetok_proxy_#{:erlang.phash2({host, port})}"

      case :inets.start(:httpc, profile: profile) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end

      :ok = :httpc.set_options([proxy: {{host, port}, []}, https_proxy: {{host, port}, []}], profile)

      http_opts =
        case creds do
          nil -> http_opts
          {user, pass} -> [{:proxy_auth, {String.to_charlist(user), String.to_charlist(pass)}} | http_opts]
        end

      {:ok, profile, http_opts}
    end
  end
end
