defmodule AgenticUi.Business.Tools.Registry do
  @moduledoc """
  Central registry for agent tools (embedded MCP pattern).

  Tools are defined in MCP-standard format (with `inputSchema`).
  Format conversion to provider-specific format is handled by the
  configured provider module (see AgenticUi.Agent.Provider).

  BUSINESS-SPECIFIC: Add/remove tools here when customizing for your use case.
  """

  @tools %{
    "search_products" => AgenticUi.Business.Tools.SearchProducts,
    "get_product_detail" => AgenticUi.Business.Tools.GetProductDetail,
    "get_categories" => AgenticUi.Business.Tools.GetCategories,
    "get_products_by_ids" => AgenticUi.Business.Tools.GetProductsByIds
  }

  @doc "Returns all tool definitions in MCP-standard format."
  def definitions do
    Enum.map(@tools, fn {_name, mod} -> mod.definition() end)
  end

  @doc "Executes a tool by name with the given arguments."
  def execute(name, args) do
    case Map.get(@tools, name) do
      nil -> {:error, "unknown tool: #{name}"}
      mod -> mod.execute(args)
    end
  end
end
