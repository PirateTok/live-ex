defmodule PirateTok.Live.Http.UA do
  @moduledoc false

  @user_agents [
    "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:138.0) Gecko/20100101 Firefox/138.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14.7; rv:139.0) Gecko/20100101 Firefox/139.0",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
  ]

  @spec random_ua() :: String.t()
  def random_ua, do: Enum.random(@user_agents)

  @spec system_timezone() :: String.t()
  def system_timezone do
    with :error <- tz_from_env(),
         :error <- tz_from_etc_timezone(),
         :error <- tz_from_localtime_link() do
      "UTC"
    end
  end

  defp tz_from_env do
    case System.get_env("TZ") do
      nil -> :error
      tz ->
        tz = String.trim(tz)
        if tz != "" and String.contains?(tz, "/"), do: tz, else: :error
    end
  end

  defp tz_from_etc_timezone do
    case File.read("/etc/timezone") do
      {:ok, content} ->
        tz = String.trim(content)
        if tz != "" and String.contains?(tz, "/"), do: tz, else: :error
      {:error, _} -> :error
    end
  end

  defp tz_from_localtime_link do
    case File.read_link("/etc/localtime") do
      {:ok, path} ->
        case String.split(path, "/zoneinfo/") do
          [_, tz] when tz != "" -> tz
          _ -> :error
        end
      {:error, _} -> :error
    end
  end
end
