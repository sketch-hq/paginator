defmodule Paginator.Ecto.Query.DescNullsLast do
  @behaviour Paginator.Ecto.Query.DynamicFilterBuilder

  import Ecto.Query

  @impl Paginator.Ecto.Query.DynamicFilterBuilder
  def build_dynamic_filter(:before, nil) do
    fn
      _, _, true ->
        raise("unstable sort order: nullable columns can't be used as the last term")

      position, binding, filters ->
        dynamic(
          [{query, position}],
          (is_nil(field(query, ^binding)) and ^filters) or not is_nil(field(query, ^binding))
        )
    end
  end

  @impl Paginator.Ecto.Query.DynamicFilterBuilder
  def build_dynamic_filter(:before, value) do
    fn
      position, binding, true ->
        dynamic(
          [{query, position}],
          field(query, ^binding) > ^value
        )

      position, binding, filters ->
        dynamic(
          [{query, position}],
          (field(query, ^binding) == ^value and ^filters) or field(query, ^binding) > ^value
        )
    end
  end

  @impl Paginator.Ecto.Query.DynamicFilterBuilder
  def build_dynamic_filter(:after, nil) do
    fn
      _, _, true ->
        raise("unstable sort order: nullable columns can't be used as the last term")

      position, binding, filters ->
        dynamic(
          [{query, position}],
          is_nil(field(query, ^binding)) and ^filters
        )
    end
  end

  @impl Paginator.Ecto.Query.DynamicFilterBuilder
  def build_dynamic_filter(:after, value) do
    fn
      position, binding, true ->
        dynamic(
          [{query, position}],
          field(query, ^binding) < ^value or is_nil(field(query, ^binding))
        )

      position, binding, filters ->
        dynamic(
          [{query, position}],
          (field(query, ^binding) == ^value and ^filters) or field(query, ^binding) < ^value or
            is_nil(field(query, ^binding))
        )
    end
  end
end
