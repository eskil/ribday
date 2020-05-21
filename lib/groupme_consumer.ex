defmodule GroupMe.Consumer do
  require Logger
  use GenStage

  def start_link do
    GenStage.start_link(__MODULE__, :state_doesnt_matter)
  end

  def init(state) do
    Logger.info("GroupMe.Consumer, init with state #{inspect(state)}")
    IO.puts("msg_id\tweek\tweekday\tdate\ttime\tuser\timg\tmessage")
    {:consumer, state}
  end

  defp get_img_url([%{type: "image", url: url}]) do
    url
  end

  defp get_img_url(_) do
    ""
  end

  defp cleanup_text(nil) do
    ""
  end

  defp cleanup_text(s) do
    String.replace(s, "\n", "")
    |> String.replace("\t", "")
    |> String.replace("\"", "\\\"")
  end

  def process_events([head|tail], to) do
    ts = Timex.from_unix(head[:created_at])
    fmt = ts
    |> Timex.to_datetime("America/Los_Angeles")
    |> Timex.format!("%V\t%a\t%F\t%T", :strftime)
    attachment = get_img_url(head[:attachments])
    IO.puts("#{head[:id]}\t#{fmt}\t\"#{head[:name]}\"\t\"#{attachment}\"\t\"#{cleanup_text(head[:text])}\"")
    case DateTime.compare(to, ts) == :lt do
      true -> process_events(tail, to)
      _ -> :stop
    end
  end

  def process_events(_, _) do
    :noreply
  end

  def handle_events(events, _from, state) do
    case process_events(events, state[:to_datetime]) do
      :stop ->
        Logger.info("GroupMe.Consumer stopping")
        {:stop, :normal, state}
      :noreply ->
        {:noreply, [], state}
    end
  end
end
