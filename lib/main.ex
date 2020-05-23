defmodule Main do
  require Logger
  @moduledoc """
  Scrapes groupme.
  """

  def main(args) do
    args |> parse_args |> process
  end

  defp logger_level(verbosity) when verbosity >= 4 do
    :debug
  end

  defp logger_level(verbosity) when verbosity >= 3 do
    :info
  end

  defp logger_level(verbosity) when verbosity >= 2 do
    :warn
  end

  defp logger_level(verbosity) when verbosity <= 1 do
    :error
  end

  def process(%Optimus.ParseResult{args: args, options: options, flags: flags}) do
    Logger.configure(level: logger_level(options[:verbosity]))
    Logger.info("Processing, args: #{inspect(args)}")
    Logger.info("Processing, options: #{inspect(options)}")
    Logger.info("Processing, flags: #{inspect(flags)}")

    # Setup producer and consumer. The producer starts scraping
    # GroupMe from the specified date (note the groupme api scrapes in
    # reverse order :-/)
    producer_state = %{
      group: options[:group],
      token: options[:token],
      before_id: options[:before_id],
      ribday_only: flags[:ribday_only],
      debug: flags[:debug],
      verbosity: flags[:verbosity]
    }
    {:ok, producer} = GenStage.start_link(GroupMe.Producer, producer_state)

    # The consumer simply just parses the returned messages and stores them.
    consumer_state = %{
      to_datetime: options[:to_datetime],
      debug: flags[:debug]
    }
    {:ok, consumer} = GenStage.start_link(GroupMe.Consumer, consumer_state)

    {:ok, _subscription} = GenStage.sync_subscribe(consumer,
      to: producer,
      cancel: :permanent,
      min_demand: 5,
      max_demand: 10)

    # Wait for consumer to end
    ref = Process.monitor(consumer)
    Logger.info("Main monitors")
    receive do
      {:DOWN, ^ref, _, _, _} ->
	      Logger.info("Process #{inspect(consumer)} is down")
    end
    Logger.info("Gentle exit")
  end

  defp parse_args(argv) do
    Optimus.new!(
      name: "ribday",
      description: "Scrapes groupme",
      version: "1.2.3",
      author: "eskil@eskil.org",
      about: "Utility to scrape ribday",
      allow_unknown_args: false,
      parse_double_dash: true,
      flags: [
        debug: [
          short: "-d",
          long: "--debug",
          help: "More verbose debugging",
          multiple: false,
          default: false
        ],
        verbosity: [
          short: "-v",
          help: "Verbosity level",
          multiple: true,
        ],
        ribday_only: [
          short: "-r",
          long: "--ribday-only",
          help: "Only scrape ribday",
          multiple: false,
        ],
      ],
      options: [
        token: [
          value_name: "TOKEN",
          short: "-T",
          long: "--token",
          help: "GroupMe X-Access-Token, find this in chrome inspector",
          parser: fn(s) ->
            case String.length(s) == 40 and String.match?(s, ~r/^[0-9a-zA-Z]+$/) do
              true -> {:ok, s}
              false -> {:error, "invalid token format, 40 chars of 0-9a-zA-Z"}
            end
          end,
          required: true
        ],
        before_id: [
          value_name: "BEFORE_ID",
          short: "-b",
          long: "--before",
          help: "Messages before this id",
          parser: :integer,
          required: false
        ],
        group: [
          value_name: "GROUP",
          short: "-g",
          long: "--group",
          help: "GroupMe group/thread id",
          parser: :integer,
          required: false,
          default: 2461547
        ],
        to_datetime: [
          value_name: "DATETIME_TO",
          short: "-t",
          long: "--to",
          help: "Scrape to this datetime (ignore messages before this)",
          parser: fn(s) ->
            case Timex.parse(s, "{ISO:Extended}") do
              {:error, _} -> {:error, "invalid datetime"}
              {:ok, _} = ok -> ok
            end
          end,
          required: false,
          default: &Date.utc_today/0
        ],
      ]
    ) |> Optimus.parse!(argv)
  end
end
