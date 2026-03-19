defmodule AgenticUi.Business.Tools.SearchProducts do
  @moduledoc "Tool: search products with optional category filter and pagination."

  alias AgenticUi.Business.Services.ProductService

  def definition do
    %{
      "name" => "search_products",
      "description" =>
        "Search products by keyword and/or category with pagination. " <>
        "Use 'query' for free-text search (e.g. 'mugs', 'wireless', 'perfume'). " <>
        "Use 'category' for exact category filtering (slug from get_categories). " <>
        "You can use both together or separately. " <>
        "IMPORTANT: When a user asks about a product type, ALWAYS search by query first to check availability before saying you don't have it.",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{
          "query" => %{
            "type" => "string",
            "description" =>
              "Free-text search keyword. Matches product names and descriptions. " <>
              "Use this when the user asks about specific products (e.g. 'do you have mugs?', 'show me wireless headphones'). " <>
              "Translate the user's query to English for best results."
          },
          "category" => %{
            "type" => "string",
            "description" => "Filter by exact category slug (e.g. 'smartphones', 'laptops'). Must match a slug from get_categories."
          },
          "page" => %{
            "type" => "integer",
            "description" => "Page number, starts at 1. Default: 1."
          },
          "per_page" => %{
            "type" => "integer",
            "description" => "Items per page. Default: 10. Max: 30."
          }
        },
        "required" => []
      }
    }
  end

  def execute(args) do
    query = Map.get(args, "query")
    category = Map.get(args, "category")
    page = Map.get(args, "page", 1)
    per_page = min(Map.get(args, "per_page", 10), 30)

    params = %{query: query, category: category, page: page, per_page: per_page}
    result = ProductService.list_products(params)

    # Fallback: when query returns 0 results and no category was given,
    # try matching the query against known category slugs.
    {result, matched_category} =
      if result.total == 0 and query && query != "" and (category == nil or category == "") do
        case match_category(query) do
          nil -> {result, nil}
          cat ->
            fallback = ProductService.list_products(%{category: cat, page: page, per_page: per_page})
            {fallback, cat}
        end
      else
        {result, nil}
      end

    compact_items =
      Enum.map(result.items, fn p ->
        %{id: p.id, name: p.name, category: p.category, price: p.price, rating: p.rating}
      end)

    response = %{
      items: compact_items,
      page: result.page,
      per_page: result.per_page,
      total: result.total,
      total_pages: result.total_pages
    }

    response = if matched_category, do: Map.put(response, :matched_category, matched_category), else: response

    response =
      cond do
        result.total == 0 and query ->
          Map.put(response, :hint, "No products found matching '#{query}'. You MUST now call get_categories and suggest related categories to the user. Never leave the user without options.")

        result.total == 0 and category ->
          Map.put(response, :hint, "No products found for category '#{category}'. This category may not exist. Call get_categories to see valid category slugs.")

        true ->
          response
      end

    {:ok, response}
  end

  # Fuzzy-match a query string against known category slugs.
  # Normalizes both to lowercase and compares with substring/token matching.
  # Returns the best matching category slug or nil.
  defp match_category(query) do
    cats = ProductService.categories()
    normalized = query |> String.downcase() |> String.replace(~r/[\s_-]+/, "-")
    tokens = query |> String.downcase() |> String.split(~r/[\s_-]+/, trim: true)

    # Exact match first (e.g. "mens-shirts" or "mens shirts")
    exact = Enum.find(cats, fn cat -> cat == normalized end)
    if exact do
      exact
    else
      # Token-based: find categories where ALL query tokens appear in the slug
      matches =
        Enum.filter(cats, fn cat ->
          Enum.all?(tokens, fn token -> String.contains?(cat, token) end)
        end)

      case matches do
        [single] -> single
        [_ | _] -> Enum.min_by(matches, &String.length/1)
        [] -> nil
      end
    end
  end
end
