defmodule GroupMe.Client do
  require Logger
  alias GroupMe.Client, as: Client

  defstruct thread: nil,
    token: nil,
    debug: nil,
    verbosity: nil

  defp get_url(%Client{thread: thread}) do
    "https://api.groupme.com/v3/groups/#{thread}/messages"
  end

  defp get_headers(%Client{token: token}) do
    [
      "Connection": "keep-alive",
      "Accept": "application/json, text/plain, */*",
      "Origin": "https://web.groupme.com",
      "X-Access-Token": "#{token}",
      "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.108 Safari/537.36",
      "Sec-Fetch-Site": "same-site",
      "Sec-Fetch-Mode": "cors",
      "Referer": "https://web.groupme.com/",
      "Accept-Encoding": "gzip, deflate, br",
      "Accept-Language": "en-US,en;q=0.9,da;q=0.8"
    ]
  end

  # Takes :limit (number of messages to fetch) and :before_id for where to start
  defp get_options(_client, params) do
    params = for {k, v} <- params, !is_nil(v), into: %{}, do: {k, v}
    [
      ssl: [{:versions, [:'tlsv1.2']}],
      recv_timeout: 500,
      params: params
    ]
  end

  defp hackney_level(%Client{debug: true, verbosity: verbosity}) when verbosity >= 4 do
    80
  end

  defp hackney_level(%Client{debug: true, verbosity: verbosity}) when verbosity >= 3 do
    60
  end

  defp hackney_level(%Client{debug: true, verbosity: verbosity}) when verbosity >= 2 do
    40
  end

  defp hackney_level(%Client{debug: true, verbosity: verbosity}) when verbosity >= 1 do
    20
  end

  defp hackney_level(%Client{debug: _, verbosity: _}) do
    0
  end

  # Takes :limit (number of messages to fetch) and :before_id for where to start
  def fetch(client, params) do
    url = get_url(client)
    headers = get_headers(client)
    options = get_options(client, params)
    Logger.debug("#{url} #{inspect(options)}")
    :hackney_trace.enable(hackney_level(client), :io)
    case HTTPoison.get(url, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        result = body
        |> :zlib.gunzip
        |> Poison.decode!
        |> Morphix.atomorphiform!
        {:ok, result}
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, 404}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
      _ ->
        {:error, nil}
    end
  end
end
