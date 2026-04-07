defmodule PirateTok.Live.Helpers.ProfileCache do
  @moduledoc """
  Cached profile fetcher — wraps sigi scraping with TTL cache + ttwid management.

  Uses an Agent for state. Start it, then call fetch/2.

  ## Usage

      {:ok, cache} = ProfileCache.start_link()
      {:ok, profile} = ProfileCache.fetch(cache, "tiktok")
      IO.puts(profile.nickname)

      # Second call is instant (cached)
      {:ok, cached} = ProfileCache.fetch(cache, "tiktok")
  """

  use Agent

  alias PirateTok.Live.Auth.Ttwid
  alias PirateTok.Live.Error
  alias PirateTok.Live.Http.Sigi

  @default_ttl_ms 300_000
  @ttwid_timeout 10_000
  @scrape_timeout 15_000

  defstruct entries: %{}, ttwid: nil, ttl_ms: @default_ttl_ms, proxy: nil, user_agent: nil, cookies: ""

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(opts \\ []) do
    state = %__MODULE__{
      ttl_ms: Keyword.get(opts, :ttl_ms, @default_ttl_ms),
      proxy: Keyword.get(opts, :proxy),
      user_agent: Keyword.get(opts, :user_agent),
      cookies: Keyword.get(opts, :cookies, "")
    }

    Agent.start_link(fn -> state end)
  end

  @spec fetch(Agent.agent(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def fetch(cache, username) do
    key = normalize_key(username)
    now = System.monotonic_time(:millisecond)

    cached_result =
      Agent.get(cache, fn state ->
        case Map.get(state.entries, key) do
          {result, ts} when now - ts < state.ttl_ms -> {:hit, result}
          _ -> :miss
        end
      end)

    case cached_result do
      {:hit, {:ok, _} = ok} -> ok
      {:hit, {:error, _} = err} -> err
      :miss -> do_fetch(cache, key, now)
    end
  end

  @spec cached(Agent.agent(), String.t()) :: map() | nil
  def cached(cache, username) do
    key = normalize_key(username)
    now = System.monotonic_time(:millisecond)

    Agent.get(cache, fn state ->
      case Map.get(state.entries, key) do
        {{:ok, profile}, ts} when now - ts < state.ttl_ms -> profile
        _ -> nil
      end
    end)
  end

  @spec invalidate(Agent.agent(), String.t()) :: :ok
  def invalidate(cache, username) do
    key = normalize_key(username)
    Agent.update(cache, fn state -> %{state | entries: Map.delete(state.entries, key)} end)
  end

  @spec invalidate_all(Agent.agent()) :: :ok
  def invalidate_all(cache) do
    Agent.update(cache, fn state -> %{state | entries: %{}} end)
  end

  defp do_fetch(cache, key, now) do
    ttwid = ensure_ttwid(cache)

    case ttwid do
      {:error, _} = err ->
        err

      {:ok, tw} ->
        {ua, cookies, proxy} = Agent.get(cache, fn s -> {s.user_agent, s.cookies, s.proxy} end)

        opts = [timeout: @scrape_timeout, cookies: cookies]
        opts = if ua, do: Keyword.put(opts, :user_agent, ua), else: opts
        opts = if proxy, do: Keyword.put(opts, :proxy, proxy), else: opts

        result = Sigi.scrape_profile(key, tw, opts)

        case result do
          {:ok, _} ->
            Agent.update(cache, fn state ->
              %{state | entries: Map.put(state.entries, key, {result, now})}
            end)

          {:error, %Error{type: t}} when t in [:profile_private, :profile_not_found, :profile_error] ->
            Agent.update(cache, fn state ->
              %{state | entries: Map.put(state.entries, key, {result, now})}
            end)

          {:error, _} ->
            :ok
        end

        result
    end
  end

  defp ensure_ttwid(cache) do
    {existing, proxy, ua} = Agent.get(cache, fn s -> {s.ttwid, s.proxy, s.user_agent} end)

    if existing do
      {:ok, existing}
    else
      opts = [timeout: @ttwid_timeout]
      opts = if ua, do: Keyword.put(opts, :user_agent, ua), else: opts
      opts = if proxy, do: Keyword.put(opts, :proxy, proxy), else: opts

      case Ttwid.fetch(opts) do
        {:ok, tw} ->
          Agent.update(cache, fn s -> %{s | ttwid: tw} end)
          {:ok, tw}

        {:error, _} = err ->
          err
      end
    end
  end

  defp normalize_key(username) do
    username |> String.trim() |> String.trim_leading("@") |> String.downcase()
  end
end
