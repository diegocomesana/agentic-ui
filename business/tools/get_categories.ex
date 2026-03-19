defmodule AgenticUi.Business.Tools.GetCategories do
  @moduledoc "Tool: get all available product categories."

  alias AgenticUi.Business.Services.ProductService

  def definition do
    %{
      "name" => "get_categories",
      "description" => "Get the list of all available product categories.",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{},
        "required" => []
      }
    }
  end

  def execute(_args) do
    {:ok, %{categories: ProductService.categories()}}
  end
end
