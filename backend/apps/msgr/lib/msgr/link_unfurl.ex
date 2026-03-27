defmodule Messngr.LinkUnfurl do
  @moduledoc """
  Extracts Open Graph metadata from URLs for rich link previews.
  Results are cached in an ETS table to avoid re-fetching.
  """

  require Logger

  @cache_ttl_ms :timer.hours(24)
  @fetch_timeout 5_000
  @max_body_bytes 256_000

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    :ets.new(__MODULE__, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end

  @doc """
  Unfurl a URL — returns Open Graph metadata or nil.
  Cached for 24 hours.
  """
  def unfurl(url) when is_binary(url) do
    case cached(url) do
      {:ok, result} -> result
      :miss ->
        result = fetch_og(url)
        cache(url, result)
        result
    end
  end

  @doc """
  Extract URLs from text and unfurl all of them.
  Returns a list of preview maps.
  """
  def unfurl_all(text) when is_binary(text) do
    extract_urls(text)
    |> Enum.take(3)
    |> Enum.map(&unfurl/1)
    |> Enum.reject(&is_nil/1)
  end

  @doc "Extract URLs from text."
  def extract_urls(text) do
    Regex.scan(~r{https?://[^\s<>\"\)]+}, text)
    |> List.flatten()
    |> Enum.uniq()
  end

  # ── Fetch ──────────────────────────────────────────────────

  defp fetch_og(url) do
    try do
      case Finch.build(:get, url, [{"user-agent", "RelayBot/1.0 (link preview)"}])
           |> Finch.request(Messngr.Finch, receive_timeout: @fetch_timeout) do
        {:ok, %{status: status, body: body, headers: headers}} when status in 200..299 ->
          content_type = get_header(headers, "content-type") || ""
          if String.contains?(content_type, "text/html") do
            parse_og(body |> String.slice(0, @max_body_bytes), url)
          else
            nil
          end

        _ -> nil
      end
    rescue
      _ -> nil
    end
  end

  defp parse_og(html, url) do
    # Simple regex-based OG tag extraction (no HTML parser dependency)
    title = extract_meta(html, "og:title") || extract_title_tag(html)
    description = extract_meta(html, "og:description") || extract_meta_name(html, "description")
    image = extract_meta(html, "og:image")
    site_name = extract_meta(html, "og:site_name")

    if title || description do
      %{
        url: url,
        title: title,
        description: description && String.slice(description, 0, 300),
        image_url: maybe_absolute_url(image, url),
        site_name: site_name || URI.parse(url).host
      }
    else
      nil
    end
  end

  defp extract_meta(html, property) do
    case Regex.run(~r{<meta[^>]*property="#{Regex.escape(property)}"[^>]*content="([^"]*)"}, html) do
      [_, content] -> content
      nil ->
        case Regex.run(~r{<meta[^>]*content="([^"]*)"[^>]*property="#{Regex.escape(property)}"}, html) do
          [_, content] -> content
          nil -> nil
        end
    end
  end

  defp extract_meta_name(html, name) do
    case Regex.run(~r{<meta[^>]*name="#{Regex.escape(name)}"[^>]*content="([^"]*)"}, html) do
      [_, content] -> content
      nil -> nil
    end
  end

  defp extract_title_tag(html) do
    case Regex.run(~r{<title[^>]*>([^<]+)</title>}i, html) do
      [_, title] -> String.trim(title)
      nil -> nil
    end
  end

  defp maybe_absolute_url(nil, _base), do: nil
  defp maybe_absolute_url(url, base) do
    uri = URI.parse(url)
    if uri.scheme do
      url
    else
      base_uri = URI.parse(base)
      URI.merge(base_uri, uri) |> to_string()
    end
  end

  defp get_header(headers, key) do
    case List.keyfind(headers, key, 0) do
      {_, value} -> value
      nil -> nil
    end
  end

  # ── Cache ──────────────────────────────────────────────────

  defp cached(url) do
    case :ets.lookup(__MODULE__, url) do
      [{_, result, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:ok, result}
        else
          :ets.delete(__MODULE__, url)
          :miss
        end
      [] -> :miss
    end
  rescue
    ArgumentError -> :miss
  end

  defp cache(url, result) do
    expires_at = System.monotonic_time(:millisecond) + @cache_ttl_ms
    :ets.insert(__MODULE__, {url, result, expires_at})
  rescue
    ArgumentError -> :ok
  end
end
