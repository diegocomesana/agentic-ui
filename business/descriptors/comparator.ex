defmodule AgenticUi.Business.Descriptors.Comparator do
  def descriptor do
    %{
      name: "Product Comparator",
      component: AgenticUi.Business.Widgets.Comparator,
      description: "Side-by-side comparison table of 2-4 products. Shows specs, price, rating differences. The agent fills the data directly.",
      config_schema: %{
        product_ids: %{type: "array", description: "List of product IDs to compare", items: "string"}
      },
      data_source: "product_service.compare_products",
      events: %{
        "remove_product" => %{description: "Remove a product from comparison", params: ["product_id"]}
      }
    }
  end
end
