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
    {:producer, Map.merge(state, %{queue: []})}
  end

  def prefill_queue(demand, queue_len, state, acc) when queue_len < demand do
    {:ok, result} =
      %GroupMe.Client{thread: state[:group], token: state[:token],
                      debug: state[:debug], verbosity: state[:verbosity]}
      |> GroupMe.Client.fetch(limit: 100, before_id: state[:before_id])
    200 = result[:meta][:code]

    messages = result[:response][:messages]
    next_before_id = Enum.at(messages, -1)[:id]
    prefill_queue(demand, queue_len + Enum.count(messages),
      %{state| before_id: next_before_id}, acc ++ messages)
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
