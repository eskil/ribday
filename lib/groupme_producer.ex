defmodule GroupMe.Producer do
  require Logger
  use GenStage

  def start_link do
    state = 0
    GenStage.start_link(__MODULE__, state, name: __MODULE__)
    # naming allows us to handle failure
  end

  def init(state) do
    Logger.info("GroupMe.Producer, init with state: #{inspect(state)}")
    {:producer, Map.merge(state, %{before_id: nil, queue: []})}
  end

  def is_a_ribday?(ts) do
    ts = Timex.from_unix(ts)
    monday = Timex.beginning_of_week(ts)
    ribday = Timex.shift(monday, days: 2)
    thursday = Timex.shift(monday, days: 3)
    Logger.debug("MON #{monday} RUB #{ribday} ts #{ts} THU #{thursday} ")
    ts in Timex.Interval.new(from: ribday, until: thursday)
  end

  def get_into_previous_ribday(ts) do
    monday = Timex.beginning_of_week(ts)
    Timex.shift(monday, days: -4, seconds: -1)
  end

  def collect_messages([head|tail], %{is_ribday: true} = state, acc) do
    case is_a_ribday?(head[:created_at]) do
      true -> collect_messages(tail, state, acc ++ [head])
      _ -> collect_messages(tail, state, acc)
    end
  end

  def collect_messages([head|tail], state, acc) do
    collect_messages(tail, state, acc ++ [head])
  end

  def collect_messages([], _, acc), do: acc

  def prefill_queue(demand, queue_len, state, acc) when queue_len < demand do
    {:ok, result} =
      %GroupMe.Client{thread: state[:group], token: state[:token],
                      debug: state[:debug], verbosity: state[:verbosity]}
      |> GroupMe.Client.fetch(limit: 100, before_id: state[:before_id])
    200 = result[:meta][:code]

    messages =
      case state[:ribday_only] do
        true -> Enum.filter(result[:response][:messages], fn msg -> is_a_ribday?(msg[:created_at]) end)
        _ -> result[:response][:messages]

      end

    next_before_id = Enum.at(messages, -1)[:id]

    prefill_queue(demand, queue_len + Enum.count(messages), %{state| before_id: next_before_id}, acc ++ messages)
  end

  def prefill_queue(demand, queue_len, _, acc) when queue_len >= demand do
    acc
  end

  def handle_demand(demand, state) do
    Logger.info("GroupMe.Producer, demand #{demand}, queue length #{inspect(Enum.count(state[:queue]))}, before #{state[:before_id]}")
    queue_tail = prefill_queue(demand, Enum.count(state[:queue]), state, [])
    queue = Enum.concat(state[:queue], queue_tail)
    last_id = Enum.at(queue, -1)[:id]
    {events, queue} = Enum.split(queue, demand)
    {:noreply, events, %{state |  before_id: last_id, queue: queue}}
  end
end
