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

  @spec system_locale() :: {String.t(), String.t()}
  def system_locale do
    result =
      with :error <- locale_from_env("LC_ALL"),
           :error <- locale_from_env("LANG") do
        {"en", "US"}
      end

    result
  end

  @spec system_language() :: String.t()
  def system_language do
    {lang, _} = system_locale()
    lang
  end

  @spec system_region() :: String.t()
  def system_region do
    {_, region} = system_locale()
    region
  end

  defp locale_from_env(var) do
    case System.get_env(var) do
      nil -> :error
      val ->
        val = String.trim(val)
        if val in ["", "C", "POSIX"], do: :error, else: parse_posix_locale(val)
    end
  end

  defp parse_posix_locale(s) do
    # strip encoding: "en_US.UTF-8" -> "en_US"
    base = s |> String.split(".") |> List.first()

    case Regex.run(~r/^([a-zA-Z]{2,})[_-]([a-zA-Z]+)/, base) do
      [_, lang, region] -> {String.downcase(lang), String.upcase(region)}
      nil ->
        if String.length(base) >= 2 do
          {String.downcase(base), "US"}
        else
          :error
        end
    end
  end
end
