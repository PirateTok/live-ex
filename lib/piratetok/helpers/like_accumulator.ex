defmodule PirateTok.Live.Helpers.LikeAccumulator do
  @moduledoc """
  Monotonizes TikTok's inconsistent `total_like_count`.

  TikTok's `total` field on like events arrives from different server shards
  with stale values, causing backwards jumps. The `count` field (per-event
  delta) is reliable.

  ## Usage

      acc = LikeAccumulator.new()

      # In your event handler:
      {stats, acc} = LikeAccumulator.process(acc, like_msg)
      IO.puts("+\#{stats.event_like_count} likes, total=\#{stats.total_like_count}")
  """

  defstruct max_total: 0, accumulated: 0

  def new, do: %__MODULE__{}

  @doc "Process a like message and return {stats, updated_accumulator}."
  def process(%__MODULE__{} = acc, %{} = msg) do
    count = msg.like_count || 0
    total = msg.total_like_count || 0

    accumulated = acc.accumulated + count
    went_backwards = total < acc.max_total
    max_total = max(total, acc.max_total)

    stats = %{
      event_like_count: count,
      total_like_count: max_total,
      accumulated_count: accumulated,
      went_backwards: went_backwards
    }

    {stats, %{acc | max_total: max_total, accumulated: accumulated}}
  end

  @doc "Clear state. For reconnect."
  def reset(%__MODULE__{}), do: new()
end
