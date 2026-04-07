defmodule PirateTok.Live.MixProject do
  use Mix.Project

  @version "0.1.4"
  @source_url "https://github.com/PirateTok/live-ex"

  def project do
    [
      app: :piratetok_live,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "TikTok Live WebSocket connector — real-time chat, gifts, likes, and viewer events. No authentication required.",
      source_url: @source_url,
      docs: [main: "PirateTok.Live", source_ref: "v#{@version}"]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :ssl, :inets]
    ]
  end

  defp deps do
    [
      {:gun, "~> 2.1"},
      {:protobuf, "~> 0.13"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "piratetok_live",
      licenses: ["0BSD"],
      links: %{"GitHub" => @source_url, "Homepage" => "https://piratetok.boats"},
      maintainers: ["Zmole Cristian"]
    ]
  end
end
