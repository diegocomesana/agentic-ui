defmodule AgenticUi.Business.Services.ProductService do
  @moduledoc """
  Product data service backed by DummyJSON API with ETS caching.
  BUSINESS-SPECIFIC: Replace this module with your own data source.
  """

  alias AgenticUi.Business.Services.{DummyJsonClient, ProductCache}

  def list_products(params \\ %{}) do
    category = Map.get(params, :category) || Map.get(params, "category")
    query = Map.get(params, :query) || Map.get(params, "query")
    page = to_int(Map.get(params, :page) || Map.get(params, "page"), 1)
    per_page = to_int(Map.get(params, :per_page) || Map.get(params, "per_page"), 6)

    skip = (page - 1) * per_page

    sort_by = Map.get(params, :sort_by) || Map.get(params, "sort_by")
    sort_order = Map.get(params, :sort_order) || Map.get(params, "sort_order")
    min_price = to_float(Map.get(params, :min_price) || Map.get(params, "min_price"), nil)
    max_price = to_float(Map.get(params, :max_price) || Map.get(params, "max_price"), nil)
    min_rating = to_float(Map.get(params, :min_rating) || Map.get(params, "min_rating"), nil)

    extra_opts =
      []
      |> then(fn o -> if sort_by, do: [{:sort_by, sort_by} | o], else: o end)
      |> then(fn o -> if sort_order, do: [{:order, sort_order} | o], else: o end)

    {items, total} =
      cond do
        query && query != "" ->
          fetch_search(query, per_page, skip)

        category && category != "" && category != "all" ->
          fetch_by_category(category, per_page, skip, extra_opts)

        true ->
          fetch_all(per_page, skip, extra_opts)
      end

    # Client-side price/rating filtering (DummyJSON doesn't support these natively)
    items = apply_local_filters(items, min_price, max_price, min_rating)

    %{
      items: items,
      page: page,
      per_page: per_page,
      total: total,
      total_pages: if(total > 0, do: ceil(total / per_page), else: 1)
    }
  end

  def get_detail(id) do
    id_str = to_string(id)
    cache_key = {:product, id_str}

    case ProductCache.get(cache_key) do
      {:ok, product} ->
        {:ok, product}

      :miss ->
        case DummyJsonClient.get_product(id_str) do
          {:ok, raw} ->
            product = normalize_product(raw)
            ProductCache.put(cache_key, product)
            {:ok, product}

          {:error, _} = err ->
            err
        end
    end
  end

  def get_products_by_ids(ids) when is_list(ids) do
    Enum.reduce(ids, [], fn id, acc ->
      case get_detail(id) do
        {:ok, product} -> acc ++ [product]
        _ -> acc
      end
    end)
  end

  def top_products(params \\ %{}) do
    category = Map.get(params, :category) || Map.get(params, "category")
    limit = to_int(Map.get(params, :limit) || Map.get(params, "limit"), 5)

    cache_key = {:top, category, limit}

    case ProductCache.get(cache_key) do
      {:ok, result} ->
        result

      :miss ->
        result =
          if category && category != "" && category != "all" do
            case DummyJsonClient.get_products_by_category_sorted(category, limit: limit, sort_by: "rating", order: "desc") do
              {:ok, %{"products" => raw}} ->
                Enum.map(raw, &normalize_product/1)
              _ ->
                []
            end
          else
            case DummyJsonClient.get_products_sorted(limit: limit, sort_by: "rating", order: "desc") do
              {:ok, %{"products" => raw}} ->
                Enum.map(raw, &normalize_product/1)
              _ ->
                []
            end
          end

        ProductCache.put(cache_key, result)
        result
    end
  end

  def categories do
    cache_key = :categories

    case ProductCache.get(cache_key) do
      {:ok, cats} ->
        cats

      :miss ->
        case DummyJsonClient.get_categories() do
          {:ok, cats} when is_list(cats) ->
            ProductCache.put(cache_key, cats)
            cats

          _ ->
            []
        end
    end
  end

  # Private

  defp fetch_all(limit, skip, extra_opts) do
    sort_by = Keyword.get(extra_opts, :sort_by)
    order = Keyword.get(extra_opts, :order)
    cache_key = {:list, nil, limit, skip, sort_by, order}

    case ProductCache.get(cache_key) do
      {:ok, result} ->
        result

      :miss ->
        opts = [limit: limit, skip: skip] ++ extra_opts

        result =
          if sort_by do
            DummyJsonClient.get_products_sorted(opts)
          else
            DummyJsonClient.get_products(limit: limit, skip: skip)
          end

        case result do
          {:ok, %{"products" => raw_products, "total" => total}} ->
            items = Enum.map(raw_products, &normalize_product/1)
            ProductCache.put(cache_key, {items, total})
            {items, total}

          _ ->
            {[], 0}
        end
    end
  end

  defp fetch_search(query, limit, skip) do
    cache_key = {:search, query, limit, skip}

    case ProductCache.get(cache_key) do
      {:ok, result} ->
        result

      :miss ->
        case DummyJsonClient.search_products(query, limit: limit, skip: skip) do
          {:ok, %{"products" => raw_products, "total" => total}} ->
            items = Enum.map(raw_products, &normalize_product/1)
            ProductCache.put(cache_key, {items, total})
            {items, total}

          _ ->
            {[], 0}
        end
    end
  end

  defp fetch_by_category(category, limit, skip, extra_opts) do
    sort_by = Keyword.get(extra_opts, :sort_by)
    order = Keyword.get(extra_opts, :order)
    cache_key = {:list, category, limit, skip, sort_by, order}

    case ProductCache.get(cache_key) do
      {:ok, result} ->
        result

      :miss ->
        opts = [limit: limit, skip: skip] ++ extra_opts

        result =
          if sort_by do
            DummyJsonClient.get_products_by_category_sorted(category, opts)
          else
            DummyJsonClient.get_products_by_category(category, limit: limit, skip: skip)
          end

        case result do
          {:ok, %{"products" => raw_products, "total" => total}} ->
            items = Enum.map(raw_products, &normalize_product/1)
            ProductCache.put(cache_key, {items, total})
            {items, total}

          _ ->
            {[], 0}
        end
    end
  end

  defp normalize_product(raw) do
    dims = raw["dimensions"] || %{}

    dimensions_str =
      if dims != %{} do
        "#{dims["width"]}W x #{dims["height"]}H x #{dims["depth"]}D cm"
      else
        nil
      end

    specs =
      %{}
      |> maybe_put("Brand", raw["brand"])
      |> maybe_put("Weight", if(raw["weight"], do: "#{raw["weight"]} g"))
      |> maybe_put("Dimensions", dimensions_str)
      |> maybe_put("Warranty", raw["warrantyInformation"])
      |> maybe_put("Shipping", raw["shippingInformation"])
      |> maybe_put("Stock", if(raw["stock"], do: "#{raw["stock"]} units"))
      |> maybe_put("SKU", raw["sku"])
      |> maybe_put("Availability", raw["availabilityStatus"])

    %{
      id: to_string(raw["id"]),
      name: raw["title"],
      category: raw["category"],
      price: raw["price"] || 0,
      rating: raw["rating"] || 0,
      image: raw["thumbnail"],
      description: raw["description"],
      specs: specs
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp to_int(nil, default), do: default
  defp to_int(v, _default) when is_integer(v), do: v

  defp to_int(v, default) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> default
    end
  end

  defp to_int(_, default), do: default

  defp to_float(nil, default), do: default
  defp to_float(v, _default) when is_float(v), do: v
  defp to_float(v, _default) when is_integer(v), do: v / 1

  defp to_float(v, default) when is_binary(v) do
    case Float.parse(v) do
      {n, _} -> n
      :error -> default
    end
  end

  defp to_float(_, default), do: default

  defp apply_local_filters(items, min_price, max_price, min_rating) do
    items
    |> then(fn items ->
      if min_price do
        Enum.filter(items, fn i -> (i.price || 0) >= min_price end)
      else
        items
      end
    end)
    |> then(fn items ->
      if max_price && max_price < 10000 do
        Enum.filter(items, fn i -> (i.price || 0) <= max_price end)
      else
        items
      end
    end)
    |> then(fn items ->
      if min_rating && min_rating > 0 do
        Enum.filter(items, fn i -> (i.rating || 0) >= min_rating end)
      else
        items
      end
    end)
  end
end
