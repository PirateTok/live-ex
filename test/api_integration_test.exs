defmodule PirateTok.ApiIntegrationTest do
  @moduledoc """
  Integration tests against real TikTok HTTP endpoints.

  Excluded by default — set env vars to opt in:

    PIRATETOK_LIVE_TEST_USER         — TikTok username that is live during the run
    PIRATETOK_LIVE_TEST_OFFLINE_USER — username that is NOT live
    PIRATETOK_LIVE_TEST_COOKIES      — "sessionid=xxx; sid_tt=xxx" for 18+ room info
    PIRATETOK_LIVE_TEST_HTTP=1       — enables the nonexistent-user probe (safe synthetic username)
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  # Deterministic synthetic username — unlikely to be registered.
  @synthetic_nonexistent "piratetok_ex_nf_7a3c9e2f1b8d4a6c0e5f3a2b1d9c8e7"

  # 25 s timeout for all TikTok API calls — CDN can be slow.
  @http_timeout 25_000

  # H3 — nonexistent user returns :user_not_found
  test "check_online nonexistent user returns user_not_found" do
    unless System.get_env("PIRATETOK_LIVE_TEST_HTTP") in ["1", "true", "yes"] do
      ExUnit.configure(exclude: [:integration])
      flunk("set PIRATETOK_LIVE_TEST_HTTP=1 to run the not-found probe (safe synthetic username)")
    end

    result = PirateTok.Live.check_online(@synthetic_nonexistent, timeout: @http_timeout)
    assert {:error, err} = result
    assert err.type == :user_not_found,
           "expected :user_not_found, got #{inspect(err.type)} — #{err.message}"
    assert String.contains?(err.message, @synthetic_nonexistent),
           "error message should contain the username"
  end

  # H1 — live user resolves to a non-empty room ID
  test "check_online live user returns room_id" do
    user = System.get_env("PIRATETOK_LIVE_TEST_USER")

    unless user && user != "" do
      flunk("set PIRATETOK_LIVE_TEST_USER=<live_username> to run this test")
    end

    clean = String.trim(user)
    result = PirateTok.Live.check_online(clean, timeout: @http_timeout)
    assert {:ok, room_id} = result
    assert is_binary(room_id), "room_id must be a string"
    assert room_id != "", "room_id must not be empty"
    assert room_id != "0", "room_id must not be '0'"
  end

  # H4 — fetch room info for a live room
  test "fetch_room_info live room returns viewers" do
    user = System.get_env("PIRATETOK_LIVE_TEST_USER")

    unless user && user != "" do
      flunk("set PIRATETOK_LIVE_TEST_USER=<live_username> to run this test")
    end

    clean = String.trim(user)

    {:ok, room_id} = PirateTok.Live.check_online(clean, timeout: @http_timeout)

    cookies_opt =
      case System.get_env("PIRATETOK_LIVE_TEST_COOKIES") do
        nil -> []
        "" -> []
        c -> [cookies: c]
      end

    result = PirateTok.Live.fetch_room_info(room_id, [{:timeout, @http_timeout} | cookies_opt])

    case result do
      {:ok, info} ->
        assert is_integer(info.viewers) or is_number(info.viewers),
               "viewers must be a number, got #{inspect(info.viewers)}"
        assert (info.viewers || 0) >= 0, "viewers must be >= 0"

      {:error, err} when err.type == :age_restricted ->
        # 18+ room without session cookies — acceptable
        assert String.contains?(err.message, "18+") or String.contains?(err.message, "age"),
               "age-restricted error should mention 18+ or age, got: #{err.message}"

      {:error, err} ->
        flunk("fetch_room_info failed: #{inspect(err)}")
    end
  end

  # H2 — offline user returns :host_not_online (not blocked, not not-found)
  test "check_online offline user returns host_not_online" do
    user = System.get_env("PIRATETOK_LIVE_TEST_OFFLINE_USER")

    unless user && user != "" do
      flunk("set PIRATETOK_LIVE_TEST_OFFLINE_USER=<offline_username> to run this test")
    end

    clean = String.trim(user)
    result = PirateTok.Live.check_online(clean, timeout: @http_timeout)
    assert {:error, err} = result
    assert err.type == :host_not_online,
           "expected :host_not_online, got #{inspect(err.type)} — #{err.message}"
    refute String.contains?(String.downcase(err.message), "ip"),
           "error must not mention IP (soy lib mistake)"
    refute String.contains?(String.downcase(err.message), "blocked"),
           "error must not say 'blocked' for an offline user"
    refute String.contains?(String.downcase(err.message), "not found"),
           "error must not say 'not found' for an offline user"
  end
end
