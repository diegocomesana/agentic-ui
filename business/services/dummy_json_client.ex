defmodule AgenticUi.Business.Services.DummyJsonClient do
  @moduledoc """
  HTTP client for DummyJSON API.
  Uses HTTPoison following the same pattern as Agent.Client.
  """
  require Logger

  def get_products(opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)
    skip = Keyword.get(opts, :skip, 0)
    get("/products?limit=#{limit}&skip=#{skip}")
  end

  def get_product(id) do
    get("/products/#{id}")
  end

  def get_products_by_category(category, opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)
    skip = Keyword.get(opts, :skip, 0)
    get("/products/category/#{category}?limit=#{limit}&skip=#{skip}")
  end

  def search_products(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)
    skip = Keyword.get(opts, :skip, 0)
    encoded = URI.encode(query)
    get("/products/search?q=#{encoded}&limit=#{limit}&skip=#{skip}")
  end

  def get_products_sorted(opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)
    skip = Keyword.get(opts, :skip, 0)
    sort_by = Keyword.get(opts, :sort_by, "rating")
    order = Keyword.get(opts, :order, "desc")
    get("/products?limit=#{limit}&skip=#{skip}&sortBy=#{sort_by}&order=#{order}")
  end

  def get_products_by_category_sorted(category, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)
    skip = Keyword.get(opts, :skip, 0)
    sort_by = Keyword.get(opts, :sort_by, "rating")
    order = Keyword.get(opts, :order, "desc")
    get("/products/category/#{category}?limit=#{limit}&skip=#{skip}&sortBy=#{sort_by}&order=#{order}")
  end

  def get_categories do
    get("/products/category-list")
  end

  defp get(path, retry_count \\ 0) do
    base_url = get_config(:base_url) || "https://dummyjson.com"
    timeout = get_config(:request_timeout) || 15_000
    max_retries = get_config(:max_retries) || 2
    url = base_url <> path

    headers = [{"Accept", "application/json"}]

    case HTTPoison.get(url, headers, recv_timeout: timeout, timeout: timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %HTTPoison.Response{status_code: code, body: err_body}} ->
        Logger.error("DummyJSON API error", status: code, body: String.slice(err_body, 0, 200))

        if code in [429, 500, 502, 503, 504] and retry_count < max_retries do
          wait = min(1000 * round(:math.pow(2, retry_count)), 10_000)
          Process.sleep(wait)
          get(path, retry_count + 1)
        else
          {:error, {:api_error, code}}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("DummyJSON network error", reason: inspect(reason))

        if retry_count < max_retries do
          wait = min(1000 * round(:math.pow(2, retry_count)), 10_000)
          Process.sleep(wait)
          get(path, retry_count + 1)
        else
          {:error, {:network_error, reason}}
        end
    end
  end

  defp get_config(key) do
    Application.get_env(:agentic_ui, __MODULE__, [])
    |> Keyword.get(key)
  end
end
