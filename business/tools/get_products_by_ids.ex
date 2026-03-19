defmodule AgenticUi.Business.Tools.GetProductsByIds do
  @moduledoc "Tool: get multiple products by their IDs (for comparisons)."

  alias AgenticUi.Business.Services.ProductService

  def definition do
    %{
      "name" => "get_products_by_ids",
      "description" => "Get full details for multiple products by their IDs. Useful for comparisons. Returns an array of product objects.",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{
          "product_ids" => %{
            "type" => "array",
            "items" => %{"type" => "string"},
            "description" => "List of product IDs to retrieve."
          }
        },
        "required" => ["product_ids"]
      }
    }
  end

  def execute(%{"product_ids" => ids}) when is_list(ids) do
    products = ProductService.get_products_by_ids(ids)
    {:ok, %{products: products}}
  end

  def execute(_), do: {:error, "missing required parameter: product_ids (array)"}
end
