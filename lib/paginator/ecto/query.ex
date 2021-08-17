defmodule Paginator.Ecto.Query do
  @moduledoc false

  import Ecto.Query

  alias Paginator.Config

  def paginate(queryable, config \\ [])

  def paginate(queryable, %Config{} = config) do
    queryable
    |> maybe_where(config)
    |> limit(^query_limit(config))
  end

  def paginate(queryable, opts) do
    config = Config.new(opts)
    paginate(queryable, config)
  end

  defp get_operator(:desc, :before, nil), do: :isnull
  defp get_operator(:desc, :before, _not_nil), do: :gt
  defp get_operator(:desc, :after, nil), do: :isnull_or_notisnull
  defp get_operator(:desc, :after, _not_nil), do: :lt
  defp get_operator(:asc, :before, nil), do: :isnull_or_notisnull
  defp get_operator(:asc, :before, _not_nil), do: :lt
  defp get_operator(:asc, :after, nil), do: :isnull
  defp get_operator(:asc, :after, _not_nil), do: :gt

  defp get_operator(direction, _, _),
    do: raise("Invalid sorting value :#{direction}, please use either :asc or :desc")

  defp get_operator_for_field(order, direction, value) do
    get_operator(order, direction, value)
  end

  # This clause is responsible for transforming legacy list cursors into map cursors
  defp filter_values(query, fields, values, cursor_direction) when is_list(values) do
    new_values =
      fields
      |> Enum.map(&elem(&1, 0))
      |> Enum.zip(values)
      |> Map.new()

    filter_values(query, fields, new_values, cursor_direction)
  end

  defp filter_values(query, fields, values, cursor_direction) when is_map(values) do
    filters = build_where_expression(query, fields, values, cursor_direction)

    where(query, [{q, 0}], ^filters)
  end

  defp build_where_expression(query, [{column, order}], values, cursor_direction) do
    value = Map.get(values, column)
    {q_position, q_binding} = column_position(query, column)

    case get_operator_for_field(order, cursor_direction, value) do
      :lt -> dynamic([{q, q_position}], field(q, ^q_binding) < ^value)
      :gt when not is_nil(value) -> dynamic([{q, q_position}], field(q, ^q_binding) > ^value)
      _ -> true
    end
  end

  defp build_where_expression(query, [{column, order} | fields], values, cursor_direction) do
    value = Map.get(values, column)
    {q_position, q_binding} = column_position(query, column)

    filters = build_where_expression(query, fields, values, cursor_direction)

    case get_operator_for_field(order, cursor_direction, value) do
      :lt ->
        dynamic(
          [{q, q_position}],
          (field(q, ^q_binding) == ^value and ^filters) or
            field(q, ^q_binding) < ^value
        )

      :gt ->
        dynamic(
          [{q, q_position}],
          (field(q, ^q_binding) == ^value and ^filters) or
            field(q, ^q_binding) > ^value or
            is_nil(field(q, ^q_binding))
        )

      :isnull ->
        dynamic([{q, q_position}], is_nil(field(q, ^q_binding)) and ^filters)

      :isnull_or_notisnull ->
        dynamic(
          [{q, q_position}],
          (is_nil(field(q, ^q_binding)) and ^filters) or
            not is_nil(field(q, ^q_binding))
        )
    end
  end

  defp maybe_where(query, %Config{
         after: nil,
         before: nil
       }) do
    query
  end

  defp maybe_where(query, %Config{
         after_values: after_values,
         before: nil,
         cursor_fields: cursor_fields
       }) do
    query
    |> filter_values(cursor_fields, after_values, :after)
  end

  defp maybe_where(query, %Config{
         after: nil,
         before_values: before_values,
         cursor_fields: cursor_fields
       }) do
    query
    |> filter_values(cursor_fields, before_values, :before)
    |> reverse_order_bys()
  end

  defp maybe_where(query, %Config{
         after_values: after_values,
         before_values: before_values,
         cursor_fields: cursor_fields
       }) do
    query
    |> filter_values(cursor_fields, after_values, :after)
    |> filter_values(cursor_fields, before_values, :before)
  end

  # Lookup position of binding in query aliases
  defp column_position(query, {binding_name, column}) do
    case Map.fetch(query.aliases, binding_name) do
      {:ok, position} ->
        {position, column}

      _ ->
        raise(
          ArgumentError,
          "Could not find binding `#{binding_name}` in query aliases: #{inspect(query.aliases)}"
        )
    end
  end

  # Without named binding we assume position of binding is 0
  defp column_position(_query, column), do: {0, column}

  #  In order to return the correct pagination cursors, we need to fetch one more
  # # record than we actually want to return.
  defp query_limit(%Config{limit: limit}) do
    limit + 1
  end

  # This code was taken from https://github.com/elixir-ecto/ecto/blob/v2.1.4/lib/ecto/query.ex#L1212-L1226
  defp reverse_order_bys(query) do
    update_in(query.order_bys, fn
      [] ->
        []

      order_bys ->
        for %{expr: expr} = order_by <- order_bys do
          %{
            order_by
            | expr:
                Enum.map(expr, fn
                  {:desc, ast} -> {:asc, ast}
                  {:desc_nulls_first, ast} -> {:asc_nulls_last, ast}
                  {:asc, ast} -> {:desc, ast}
                  {:asc_nulls_last, ast} -> {:desc_nulls_first, ast}
                end)
          }
        end
    end)
  end
end
