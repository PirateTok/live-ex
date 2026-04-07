defmodule PirateTok.Live.Helpers.GiftStreakTracker do
  @moduledoc """
  Tracks gift streak deltas from TikTok's running totals.

  TikTok combo gifts fire multiple events during a streak, each carrying a
  running total in `repeat_count` (2, 4, 7, 7). This helper tracks active
  streaks by `group_id` and computes the delta per event.

  ## Usage

      tracker = GiftStreakTracker.new()

      # In your event handler:
      {enriched, tracker} = GiftStreakTracker.process(tracker, gift_msg)
      IO.puts("streak \#{enriched.streak_id} — +\#{enriched.event_gift_count} gifts")
  """

  @stale_secs 60

  defstruct streaks: %{}

  def new, do: %__MODULE__{}

  @doc "Process a gift message and return {enriched_event, updated_tracker}."
  def process(%__MODULE__{} = tracker, %{} = msg) do
    gift_details = msg.gift_details || %{}
    diamond_per = Map.get(gift_details, :diamond_count, 0) || 0
    gift_type = Map.get(gift_details, :gift_type, 0) || 0
    is_combo = gift_type == 1
    repeat_end = msg.repeat_end || 0
    is_final = repeat_end == 1
    group_id = msg.group_id || 0
    repeat_count = msg.repeat_count || 0

    if not is_combo do
      event = %{
        streak_id: group_id,
        is_active: false,
        is_final: true,
        event_gift_count: 1,
        total_gift_count: 1,
        event_diamond_count: diamond_per,
        total_diamond_count: diamond_per
      }

      {event, tracker}
    else
      now = System.monotonic_time(:second)
      streaks = evict_stale(tracker.streaks, now)

      prev_count =
        case Map.get(streaks, group_id) do
          {count, _ts} -> count
          nil -> 0
        end

      delta = max(repeat_count - prev_count, 0)

      streaks =
        if is_final do
          Map.delete(streaks, group_id)
        else
          Map.put(streaks, group_id, {repeat_count, now})
        end

      rc = max(repeat_count, 1)

      event = %{
        streak_id: group_id,
        is_active: not is_final,
        is_final: is_final,
        event_gift_count: delta,
        total_gift_count: repeat_count,
        event_diamond_count: diamond_per * delta,
        total_diamond_count: diamond_per * rc
      }

      {event, %{tracker | streaks: streaks}}
    end
  end

  @doc "Number of currently active (non-finalized) streaks."
  def active_streaks(%__MODULE__{streaks: streaks}), do: map_size(streaks)

  @doc "Clear all tracked state. For reconnect scenarios."
  def reset(%__MODULE__{}), do: new()

  defp evict_stale(streaks, now) do
    Map.reject(streaks, fn {_id, {_count, ts}} -> now - ts >= @stale_secs end)
  end
end
