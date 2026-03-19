defmodule AgenticUi.Business.Descriptors.Registry do
  @moduledoc """
  Central registry for widget descriptors.
  BUSINESS-SPECIFIC: Add/remove widget types here when customizing for your use case.
  """

  @chat_widgets %{
    "chat_category_button" => AgenticUi.Business.Descriptors.ChatCategoryButton,
    "chat_product_card" => AgenticUi.Business.Descriptors.ChatProductCard
  }

  @descriptors %{
    "product_grid" => AgenticUi.Business.Descriptors.ProductGrid,
    "product_detail" => AgenticUi.Business.Descriptors.ProductDetail,
    "comparator" => AgenticUi.Business.Descriptors.Comparator,
    "hero_banner" => AgenticUi.Business.Descriptors.HeroBanner,
    "category_browser" => AgenticUi.Business.Descriptors.CategoryBrowser,
    "hero_carousel" => AgenticUi.Business.Descriptors.HeroCarousel,
    "product_carousel" => AgenticUi.Business.Descriptors.ProductCarousel,
    "top_products" => AgenticUi.Business.Descriptors.TopProducts,
    "cart" => AgenticUi.Business.Descriptors.Cart,
    "wishlist" => AgenticUi.Business.Descriptors.Wishlist,
    "search_bar" => AgenticUi.Business.Descriptors.SearchBar,
    "main_menu" => AgenticUi.Business.Descriptors.MainMenu
  }

  def get(type), do: Map.get(@descriptors, type)

  def all do
    Enum.map(@descriptors, fn {type, mod} ->
      Map.put(mod.descriptor(), :type, type)
    end)
  end

  def catalog_for_agent do
    all()
    |> Enum.map(fn d ->
      %{
        type: d.type,
        name: d.name,
        description: d.description,
        config_schema: d[:config_schema] || %{},
        data_source: d[:data_source]
      }
    end)
  end

  def agent_instructions do
    all()
    |> Enum.filter(fn d -> d[:agent_instructions] end)
    |> Enum.map(fn d -> "- **#{d.type}**: #{d[:agent_instructions]}" end)
    |> Enum.join("\n")
  end

  @doc "Returns all widget type names as a pipe-separated string for prompt templates."
  def widget_type_names do
    @descriptors |> Map.keys() |> Enum.sort() |> Enum.map_join(" | ", &inspect/1)
  end

  @doc "Returns the component module for a widget type, or nil."
  def component_for(type) do
    case Map.get(@descriptors, type) do
      nil -> nil
      mod -> mod.descriptor()[:component]
    end
  end

  # --- Chat Widgets ---

  def get_chat_widget(type), do: Map.get(@chat_widgets, type)

  def all_chat_widgets do
    Enum.map(@chat_widgets, fn {type, mod} ->
      Map.put(mod.descriptor(), :type, type)
    end)
  end

  def chat_widget_catalog_for_agent do
    all_chat_widgets()
    |> Enum.map(fn d ->
      %{
        type: d.type,
        name: d.name,
        description: d.description,
        config_schema: d[:config_schema] || %{}
      }
    end)
  end

  def chat_widget_type_names do
    @chat_widgets |> Map.keys() |> Enum.sort() |> Enum.map_join(" | ", &inspect/1)
  end

  def chat_widget_component_for(type) do
    case Map.get(@chat_widgets, type) do
      nil -> nil
      mod -> mod.descriptor()[:component]
    end
  end
end
