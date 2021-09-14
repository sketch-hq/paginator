defmodule Paginator.Ecto.Query.DynamicFilterBuilder do
  @type dynamic_filter_builder :: (integer(), term(), Ecto.Query.t() -> Ecto.Query.t())

  @callback build_dynamic_filter(:after | :before, term()) :: dynamic_filter_builder()

  @dispatch_table %{
    desc: Paginator.Ecto.Query.DescNullsFirst,
    desc_nulls_first: Paginator.Ecto.Query.DescNullsFirst,
    desc_nulls_last: Paginator.Ecto.Query.DescNullsLast,
    asc: Paginator.Ecto.Query.AscNullsLast,
    asc_nulls_last: Paginator.Ecto.Query.AscNullsLast,
    asc_nulls_first: Paginator.Ecto.Query.AscNullsFirst
  }

  @spec builder!(atom(), :after | :before, term()) :: dynamic_filter_builder()
  def builder!(sort_order, direction, value) do
    case Map.fetch(@dispatch_table, sort_order) do
      {:ok, module} ->
        apply(module, :build_dynamic_filter, [direction, value])

      :error ->
        available_sort_orders = Map.keys(@dispatch_table) |> Enum.join(", ")

        raise(
          "Invalid sorting value :#{sort_order}, please please use either #{available_sort_orders}"
        )
    end
  end
end
