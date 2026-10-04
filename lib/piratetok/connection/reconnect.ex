defmodule PirateTok.Live.Connection.Reconnect do
  @moduledoc false
  # Pure reconnect policy. `max_retries` bounds *consecutive* failures:
  # a healthy session (up >= 30 s) resets the counter. The ttwid + UA session
  # is kept across reconnects and dropped only on DEVICE_BLOCKED or a
  # short-lived (unhealthy) attempt.

  @healthy_session_ms 30_000
  @device_blocked_delay_ms 2_000
  @max_backoff_ms 30_000

  @type outcome :: :healthy | :failed | :blocked
  @type decision ::
          {:retry, attempt :: pos_integer(), delay_ms :: pos_integer(), keep_session? :: boolean()}
          | :give_up

  @spec healthy_session_ms() :: pos_integer()
  def healthy_session_ms, do: @healthy_session_ms

  @doc "Classify a finished WSS attempt from its result and how long it ran."
  @spec classify(term(), non_neg_integer()) :: outcome()
  def classify({:error, %PirateTok.Live.Error{type: :device_blocked}}, _elapsed_ms), do: :blocked
  def classify(_result, elapsed_ms) when elapsed_ms >= @healthy_session_ms, do: :healthy
  def classify(_result, _elapsed_ms), do: :failed

  @spec decide(non_neg_integer(), outcome(), non_neg_integer()) :: decision()
  def decide(attempt, outcome, max_retries) do
    next = if outcome == :healthy, do: 1, else: attempt + 1

    if next > max_retries do
      :give_up
    else
      {:retry, next, delay_ms(next, outcome), outcome == :healthy}
    end
  end

  defp delay_ms(_attempt, :blocked), do: @device_blocked_delay_ms
  defp delay_ms(attempt, _outcome), do: min(1_000 * Integer.pow(2, attempt), @max_backoff_ms)
end
