defmodule AgenticUi.Business.Tools.GetProductDetail do
  @moduledoc "Tool: get full product details by ID."

  alias AgenticUi.Business.Services.ProductService

  def definition do
    %{
      "name" => "get_product_detail",
      "description" => "Get full details for a single product by ID. Returns name, category, price, rating, description, image, and specs.",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{
          "product_id" => %{
            "type" => "string",
            "description" => "The product ID."
          }
        },
        "required" => ["product_id"]
      }
    }
  end

  def execute(%{"product_id" => id}) do
    case ProductService.get_detail(id) do
      {:ok, product} -> {:ok, product}
      {:error, reason} -> {:error, reason}
    end
  end

  def execute(_), do: {:error, "missing required parameter: product_id"}
end
