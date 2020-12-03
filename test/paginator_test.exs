defmodule PaginatorTest do
  use Paginator.DataCase
  doctest Paginator

  alias Calendar.DateTime, as: DT

  alias Paginator.Cursor

  setup :create_data

  test "paginates forward", %{
    payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
  } do
    opts = [cursor_fields: [:charged_at, :id], sort_direction: :asc, limit: 4]

    page = payments_by_charged_at() |> Repo.paginate(opts)
    assert to_ids(page.entries) == to_ids([p5, p4, p1, p6])
    assert page.metadata.after == encode_cursor(%{charged_at: p6.charged_at, id: p6.id})

    page = payments_by_charged_at() |> Repo.paginate(opts ++ [after: page.metadata.after])
    assert to_ids(page.entries) == to_ids([p7, p3, p10, p2])
    assert page.metadata.after == encode_cursor(%{charged_at: p2.charged_at, id: p2.id})

    page = payments_by_charged_at() |> Repo.paginate(opts ++ [after: page.metadata.after])
    assert to_ids(page.entries) == to_ids([p12, p8, p9, p11])
    assert page.metadata.after == nil
  end

  test "paginates forward with legacy cursor", %{
    payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
  } do
    opts = [cursor_fields: [:charged_at, :id], sort_direction: :asc, limit: 4]

    page = payments_by_charged_at() |> Repo.paginate(opts)
    assert to_ids(page.entries) == to_ids([p5, p4, p1, p6])
    assert %{charged_at: charged_at, id: id} = Cursor.decode(page.metadata.after)
    assert charged_at == p6.charged_at
    assert id == p6.id

    legacy_cursor = encode_legacy_cursor([charged_at, id])

    page = payments_by_charged_at() |> Repo.paginate(opts ++ [after: legacy_cursor])
    assert to_ids(page.entries) == to_ids([p7, p3, p10, p2])
    assert %{charged_at: charged_at, id: id} = Cursor.decode(page.metadata.after)
    assert charged_at == p2.charged_at
    assert id == p2.id

    legacy_cursor = encode_legacy_cursor([charged_at, id])

    page = payments_by_charged_at() |> Repo.paginate(opts ++ [after: legacy_cursor])
    assert to_ids(page.entries) == to_ids([p12, p8, p9, p11])
    assert page.metadata.after == nil
  end

  test "paginates backward", %{
    payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
  } do
    opts = [cursor_fields: [:charged_at, :id], sort_direction: :asc, limit: 4]

    page =
      payments_by_charged_at()
      |> Repo.paginate(opts ++ [before: encode_cursor(%{charged_at: p11.charged_at, id: p11.id})])

    assert to_ids(page.entries) == to_ids([p2, p12, p8, p9])
    assert page.metadata.before == encode_cursor(%{charged_at: p2.charged_at, id: p2.id})

    page = payments_by_charged_at() |> Repo.paginate(opts ++ [before: page.metadata.before])
    assert to_ids(page.entries) == to_ids([p6, p7, p3, p10])
    assert page.metadata.before == encode_cursor(%{charged_at: p6.charged_at, id: p6.id})

    page = payments_by_charged_at() |> Repo.paginate(opts ++ [before: page.metadata.before])
    assert to_ids(page.entries) == to_ids([p5, p4, p1])
    assert page.metadata.after == encode_cursor(%{charged_at: p1.charged_at, id: p1.id})
    assert page.metadata.before == nil
  end

  test "returns an empty page when there are no results" do
    page =
      payments_by_status("failed")
      |> Repo.paginate(cursor_fields: [:charged_at, :id], limit: 10)

    assert page.entries == []
    assert page.metadata.after == nil
    assert page.metadata.before == nil
  end

  describe "paginate a collection of payments, sorting by charged_at" do
    test "sorts ascending without cursors", %{
      payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_charged_at()
        |> Repo.paginate(cursor_fields: [:charged_at, :id], sort_direction: :asc, limit: 50)

      assert to_ids(entries) == to_ids([p5, p4, p1, p6, p7, p3, p10, p2, p12, p8, p9, p11])
      assert metadata == %Metadata{after: nil, before: nil, limit: 50}
    end

    test "sorts ascending with before cursor", %{
      payments: {p1, p2, p3, _p4, _p5, p6, p7, p8, p9, p10, _p11, p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_charged_at()
        |> Repo.paginate(
          cursor_fields: [:charged_at, :id],
          sort_direction: :asc,
          before: encode_cursor(%{charged_at: p9.charged_at, id: p9.id}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([p1, p6, p7, p3, p10, p2, p12, p8])

      assert metadata == %Metadata{
               after: encode_cursor(%{charged_at: p8.charged_at, id: p8.id}),
               before: encode_cursor(%{charged_at: p1.charged_at, id: p1.id}),
               limit: 8
             }
    end

    test "sorts create_customers_and_payments ascending with after cursor", %{
      payments: {_p1, p2, p3, _p4, _p5, _p6, _p7, p8, p9, p10, p11, p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_charged_at()
        |> Repo.paginate(
          cursor_fields: [:charged_at, :id],
          sort_direction: :asc,
          after: encode_cursor(%{charged_at: p3.charged_at, id: p3.id}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([p10, p2, p12, p8, p9, p11])

      assert metadata == %Metadata{
               after: nil,
               before: encode_cursor(%{charged_at: p10.charged_at, id: p10.id}),
               limit: 8
             }
    end

    test "sorts ascending with before and after cursor", %{
      payments: {_p1, p2, p3, _p4, _p5, _p6, _p7, p8, _p9, p10, _p11, p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_charged_at()
        |> Repo.paginate(
          cursor_fields: [:charged_at, :id],
          sort_direction: :asc,
          after: encode_cursor(%{charged_at: p3.charged_at, id: p3.id}),
          before: encode_cursor(%{charged_at: p8.charged_at, id: p8.id}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([p10, p2, p12])

      assert metadata == %Metadata{
               after: encode_cursor(%{charged_at: p12.charged_at, id: p12.id}),
               before: encode_cursor(%{charged_at: p10.charged_at, id: p10.id}),
               limit: 8
             }
    end

    test "sorts descending without cursors", %{
      payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_charged_at(:desc)
        |> Repo.paginate(cursor_fields: [:charged_at, :id], sort_direction: :desc, limit: 50)

      assert to_ids(entries) == to_ids([p11, p9, p8, p12, p2, p10, p3, p7, p6, p1, p4, p5])
      assert metadata == %Metadata{after: nil, before: nil, limit: 50}
    end

    test "sorts descending with before cursor", %{
      payments: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, p9, _p10, p11, _p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_charged_at(:desc)
        |> Repo.paginate(
          cursor_fields: [:charged_at, :id],
          sort_direction: :desc,
          before: encode_cursor(%{charged_at: p9.charged_at, id: p9.id}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([p11])

      assert metadata == %Metadata{
               after: encode_cursor(%{charged_at: p11.charged_at, id: p11.id}),
               before: nil,
               limit: 8
             }
    end

    test "sorts descending with after cursor", %{
      payments: {p1, p2, p3, _p4, _p5, p6, p7, p8, p9, p10, _p11, p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_charged_at(:desc)
        |> Repo.paginate(
          cursor_fields: [:charged_at, :id],
          sort_direction: :desc,
          after: encode_cursor(%{charged_at: p9.charged_at, id: p9.id}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([p8, p12, p2, p10, p3, p7, p6, p1])

      assert metadata == %Metadata{
               after: encode_cursor(%{charged_at: p1.charged_at, id: p1.id}),
               before: encode_cursor(%{charged_at: p8.charged_at, id: p8.id}),
               limit: 8
             }
    end

    test "sorts descending with before and after cursor", %{
      payments: {_p1, p2, p3, _p4, _p5, _p6, _p7, p8, p9, p10, _p11, p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_charged_at(:desc)
        |> Repo.paginate(
          cursor_fields: [:charged_at, :id],
          sort_direction: :desc,
          after: encode_cursor(%{charged_at: p9.charged_at, id: p9.id}),
          before: encode_cursor(%{charged_at: p3.charged_at, id: p3.id}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([p8, p12, p2, p10])

      assert metadata == %Metadata{
               after: encode_cursor(%{charged_at: p10.charged_at, id: p10.id}),
               before: encode_cursor(%{charged_at: p8.charged_at, id: p8.id}),
               limit: 8
             }
    end

    test "sorts ascending with before cursor at beginning of collection", %{
      payments: {_p1, _p2, _p3, _p4, p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_charged_at()
        |> Repo.paginate(
          cursor_fields: [:charged_at, :id],
          sort_direction: :asc,
          before: encode_cursor(%{charged_at: p5.charged_at, id: p5.id}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([])
      assert metadata == %Metadata{after: nil, before: nil, limit: 8}
    end

    test "sorts ascending with after cursor at end of collection", %{
      payments: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, p11, _p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_charged_at()
        |> Repo.paginate(
          cursor_fields: [:charged_at, :id],
          sort_direction: :asc,
          after: encode_cursor(%{charged_at: p11.charged_at, id: p11.id}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([])
      assert metadata == %Metadata{after: nil, before: nil, limit: 8}
    end

    test "sorts descending with before cursor at beginning of collection", %{
      payments: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, p11, _p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_charged_at(:desc)
        |> Repo.paginate(
          cursor_fields: [:charged_at, :id],
          sort_direction: :desc,
          before: encode_cursor(%{charged_at: p11.charged_at, id: p11.id}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([])
      assert metadata == %Metadata{after: nil, before: nil, limit: 8}
    end

    test "sorts descending with after cursor at end of collection", %{
      payments: {_p1, _p2, _p3, _p4, p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_charged_at(:desc)
        |> Repo.paginate(
          cursor_fields: [:charged_at, :id],
          sort_direction: :desc,
          after: encode_cursor(%{charged_at: p5.charged_at, id: p5.id}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([])
      assert metadata == %Metadata{after: nil, before: nil, limit: 8}
    end
  end

  describe "paginate a collection of payments with customer filter, sorting by amount, charged_at" do
    test "multiple cursor_fields with pre-existing where filter in query", %{
      customers: {c1, _c2, _c3},
      payments: {_p1, _p2, _p3, _p4, p5, p6, p7, p8, _p9, _p10, _p11, _p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        customer_payments_by_charged_at_and_amount(c1)
        |> Repo.paginate(cursor_fields: [:charged_at, :amount, :id], limit: 2)

      assert to_ids(entries) == to_ids([p5, p6])

      %Page{entries: entries, metadata: _metadata} =
        customer_payments_by_charged_at_and_amount(c1)
        |> Repo.paginate(
          cursor_fields: [:charged_at, :amount, :id],
          limit: 2,
          after: metadata.after
        )

      assert to_ids(entries) == to_ids([p7, p8])
    end

    test "before cursor with multiple cursor_fields and pre-existing where filter in query", %{
      customers: {c1, _c2, _c3},
      payments: {_p1, _p2, _p3, _p4, _p5, p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      assert %Page{entries: [], metadata: _metadata} =
               customer_payments_by_charged_at_and_amount(c1)
               |> Repo.paginate(
                 cursor_fields: [:amount, :charged_at, :id],
                 before:
                   encode_cursor(%{amount: p6.amount, charged_at: p6.charged_at, id: p6.id}),
                 limit: 1
               )
    end
  end

  describe "paginate a collection of payments, sorting by customer name" do
    test "raises error when binding not found", %{
      payments: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, p11, _p12}
    } do
      assert_raise ArgumentError,
                   "Could not find binding `bogus_binding` in query aliases: %{customer: 1, payments: 0}",
                   fn ->
                     %Page{} =
                       payments_by_customer_name()
                       |> Repo.paginate(
                         cursor_fields: [
                           {{:bogus_binding, :id}, :asc},
                           {{:bogus_binding, :name}, :asc}
                         ],
                         limit: 50,
                         before:
                           encode_cursor(%{
                             {:bogus_binding, :id} => p11.id,
                             {:bogus_binding, :name} => p11.customer.name
                           })
                       )
                   end
    end

    test "sorts with mixed bindingless, bound columns", %{
      payments: {_p1, _p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, _p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [{:id, :asc}, {{:customer, :name}, :asc}],
          before: encode_cursor(%{:id => p11.id, {:customer, :name} => p11.customer.name}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([p3, p4, p5, p6, p7, p8, p9, p10])

      assert metadata == %Metadata{
               after: encode_cursor(%{:id => p10.id, {:customer, :name} => p10.customer.name}),
               before: encode_cursor(%{:id => p3.id, {:customer, :name} => p3.customer.name}),
               limit: 8
             }
    end

    test "sorts with mixed columns without direction and bound columns", %{
      payments: {_p1, _p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, _p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [:id, {{:customer, :name}, :asc}],
          before: encode_cursor(%{:id => p11.id, {:customer, :name} => p11.customer.name}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([p3, p4, p5, p6, p7, p8, p9, p10])

      assert metadata == %Metadata{
               after: encode_cursor(%{:id => p10.id, {:customer, :name} => p10.customer.name}),
               before: encode_cursor(%{:id => p3.id, {:customer, :name} => p3.customer.name}),
               limit: 8
             }
    end

    test "sorts ascending without cursors", %{
      payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :asc}, {{:customer, :name}, :asc}],
          limit: 50
        )

      assert to_ids(entries) == to_ids([p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12])
      assert metadata == %Metadata{after: nil, before: nil, limit: 50}
    end

    test "sorts ascending with before cursor", %{
      payments: {_p1, _p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, _p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :asc}, {{:customer, :name}, :asc}],
          before:
            encode_cursor(%{{:payments, :id} => p11.id, {:customer, :name} => p11.customer.name}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([p3, p4, p5, p6, p7, p8, p9, p10])

      assert metadata == %Metadata{
               after:
                 encode_cursor(%{
                   {:payments, :id} => p10.id,
                   {:customer, :name} => p10.customer.name
                 }),
               before:
                 encode_cursor(%{
                   {:payments, :id} => p3.id,
                   {:customer, :name} => p3.customer.name
                 }),
               limit: 8
             }
    end

    test "sorts ascending with after cursor", %{
      payments: {_p1, _p2, _p3, _p4, _p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :asc}, {{:customer, :name}, :asc}],
          after:
            encode_cursor(%{{:payments, :id} => p6.id, {:customer, :name} => p6.customer.name}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([p7, p8, p9, p10, p11, p12])

      assert metadata == %Metadata{
               after: nil,
               before:
                 encode_cursor(%{
                   {:payments, :id} => p7.id,
                   {:customer, :name} => p7.customer.name
                 }),
               limit: 8
             }
    end

    test "sorts ascending with before and after cursor", %{
      payments: {_p1, _p2, _p3, _p4, _p5, p6, p7, p8, p9, p10, _p11, _p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :asc}, {{:customer, :name}, :asc}],
          after:
            encode_cursor(%{{:payments, :id} => p6.id, {:customer, :name} => p6.customer.name}),
          before:
            encode_cursor(%{{:payments, :id} => p10.id, {:customer, :name} => p10.customer.name}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([p7, p8, p9])

      assert metadata == %Metadata{
               after:
                 encode_cursor(%{
                   {:payments, :id} => p9.id,
                   {:customer, :name} => p9.customer.name
                 }),
               before:
                 encode_cursor(%{
                   {:payments, :id} => p7.id,
                   {:customer, :name} => p7.customer.name
                 }),
               limit: 8
             }
    end

    test "sorts descending without cursors", %{
      payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_customer_name(:desc, :desc)
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :desc}, {{:customer, :name}, :desc}],
          limit: 50
        )

      assert to_ids(entries) == to_ids([p12, p11, p10, p9, p8, p7, p6, p5, p4, p3, p2, p1])
      assert metadata == %Metadata{after: nil, before: nil, limit: 50}
    end

    test "sorts descending with before cursor", %{
      payments: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, p11, p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_customer_name(:desc)
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :desc}, {{:customer, :name}, :desc}],
          before:
            encode_cursor(%{{:payments, :id} => p11.id, {:customer, :name} => p11.customer.name}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([p12])

      assert metadata == %Metadata{
               after:
                 encode_cursor(%{
                   {:payments, :id} => p12.id,
                   {:customer, :name} => p12.customer.name
                 }),
               before: nil,
               limit: 8
             }
    end

    test "sorts descending with after cursor", %{
      payments: {_p1, _p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, _p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_customer_name(:desc, :desc)
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :desc}, {{:customer, :name}, :desc}],
          sort_direction: :desc,
          after:
            encode_cursor(%{{:payments, :id} => p11.id, {:customer, :name} => p11.customer.name}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([p10, p9, p8, p7, p6, p5, p4, p3])

      assert metadata == %Metadata{
               after:
                 encode_cursor(%{
                   {:payments, :id} => p3.id,
                   {:customer, :name} => p3.customer.name
                 }),
               before:
                 encode_cursor(%{
                   {:payments, :id} => p10.id,
                   {:customer, :name} => p10.customer.name
                 }),
               limit: 8
             }
    end

    test "sorts descending with before and after cursor", %{
      payments: {_p1, _p2, _p3, _p4, _p5, p6, p7, p8, p9, p10, p11, _p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_customer_name(:desc, :desc)
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :desc}, {{:customer, :name}, :desc}],
          after:
            encode_cursor(%{{:payments, :id} => p11.id, {:customer, :name} => p11.customer.name}),
          before:
            encode_cursor(%{{:payments, :id} => p6.id, {:customer, :name} => p6.customer.name}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([p10, p9, p8, p7])

      assert metadata == %Metadata{
               after:
                 encode_cursor(%{
                   {:payments, :id} => p7.id,
                   {:customer, :name} => p7.customer.name
                 }),
               before:
                 encode_cursor(%{
                   {:payments, :id} => p10.id,
                   {:customer, :name} => p10.customer.name
                 }),
               limit: 8
             }
    end

    test "sorts ascending with before cursor at beginning of collection", %{
      payments: {p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :asc}, {{:customer, :name}, :asc}],
          before:
            encode_cursor(%{{:payments, :id} => p1.id, {:customer, :name} => p1.customer.name}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([])
      assert metadata == %Metadata{after: nil, before: nil, limit: 8}
    end

    test "sorts ascending with after cursor at end of collection", %{
      payments: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, _p11, p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :asc}, {{:customer, :name}, :asc}],
          after:
            encode_cursor(%{{:payments, :id} => p12.id, {:customer, :name} => p12.customer.name}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([])
      assert metadata == %Metadata{after: nil, before: nil, limit: 8}
    end

    test "sorts descending with before cursor at beginning of collection", %{
      payments: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, _p11, p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_customer_name(:desc, :desc)
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :desc}, {{:customer, :name}, :desc}],
          before:
            encode_cursor(%{{:payments, :id} => p12.id, {:customer, :name} => p12.customer.name}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([])
      assert metadata == %Metadata{after: nil, before: nil, limit: 8}
    end

    test "sorts descending with after cursor at end of collection", %{
      payments: {p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_customer_name(:desc, :desc)
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :desc}, {{:customer, :name}, :desc}],
          after:
            encode_cursor(%{{:payments, :id} => p1.id, {:customer, :name} => p1.customer.name}),
          limit: 8
        )

      assert to_ids(entries) == to_ids([])
      assert metadata == %Metadata{after: nil, before: nil, limit: 8}
    end

    test "sorts on 2nd level join column with a custom cursor value function", %{
      payments: {_p1, _p2, _p3, _p4, p5, p6, p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_address_city()
        |> Repo.paginate(
          cursor_fields: [{{:address, :city}, :asc}, id: :asc],
          before: nil,
          limit: 3,
          fetch_cursor_value_fun: fn
            schema, {:address, :city} ->
              schema.customer.address.city

            schema, field ->
              Paginator.default_fetch_cursor_value(schema, field)
          end
        )

      assert to_ids(entries) == to_ids([p5, p6, p7])

      p7 = Repo.preload(p7, customer: :address)

      assert metadata == %Metadata{
               after:
                 encode_cursor(%{{:address, :city} => p7.customer.address.city, :id => p7.id}),
               before: nil,
               limit: 3
             }
    end

    test "sorts with respect to nil values", %{
      payments: {_p1, _p2, _p3, _p4, _p5, _p6, p7, _p8, _p9, _p10, p11, _p12}
    } do
      %Page{entries: entries, metadata: metadata} =
        payments_by_charged_at(:desc)
        |> Repo.paginate(
          cursor_fields: [:charged_at, :id],
          sort_direction: :desc,
          after: encode_cursor(%{charged_at: nil, id: nil}),
          limit: 8
        )

      assert Enum.count(entries) == 8

      assert metadata == %Metadata{
               before: encode_cursor(%{charged_at: p11.charged_at, id: p11.id}),
               limit: 8,
               after: encode_cursor(%{charged_at: p7.charged_at, id: p7.id})
             }
    end
  end

  test "applies a default limit if none is provided", %{
    payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
  } do
    %Page{entries: entries, metadata: metadata} =
      payments_by_customer_name()
      |> Repo.paginate(cursor_fields: [:id], sort_direction: :asc)

    assert to_ids(entries) == to_ids([p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12])
    assert metadata == %Metadata{after: nil, before: nil, limit: 50}
  end

  test "enforces the minimum limit", %{
    payments: {p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
  } do
    %Page{entries: entries, metadata: metadata} =
      payments_by_customer_name()
      |> Repo.paginate(cursor_fields: [:id], sort_direction: :asc, limit: 0)

    assert to_ids(entries) == to_ids([p1])
    assert metadata == %Metadata{after: encode_cursor(%{id: p1.id}), before: nil, limit: 1}
  end

  describe "with include_total_count" do
    test "when set to :infinity", %{
      payments: {_p1, _p2, _p3, _p4, p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{metadata: metadata} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [:id],
          sort_direction: :asc,
          limit: 5,
          total_count_limit: :infinity,
          include_total_count: true
        )

      assert metadata == %Metadata{
               after: encode_cursor(%{id: p5.id}),
               before: nil,
               limit: 5,
               total_count: 12,
               total_count_cap_exceeded: false
             }
    end

    test "when cap not exceeded", %{
      payments: {_p1, _p2, _p3, _p4, p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{metadata: metadata} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [:id],
          sort_direction: :asc,
          limit: 5,
          include_total_count: true
        )

      assert metadata == %Metadata{
               after: encode_cursor(%{id: p5.id}),
               before: nil,
               limit: 5,
               total_count: 12,
               total_count_cap_exceeded: false
             }
    end

    test "when cap exceeded", %{
      payments: {_p1, _p2, _p3, _p4, p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{metadata: metadata} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [:id],
          sort_direction: :asc,
          limit: 5,
          include_total_count: true,
          total_count_limit: 10
        )

      assert metadata == %Metadata{
               after: encode_cursor(%{id: p5.id}),
               before: nil,
               limit: 5,
               total_count: 10,
               total_count_cap_exceeded: true
             }
    end

    test "when custom total_count_primary_key_field", %{
      addresses: {_a1, a2, _a3}
    } do
      %Page{metadata: metadata} =
        from(a in Address, select: a)
        |> Repo.paginate(
          cursor_fields: [:city],
          sort_direction: :asc,
          limit: 2,
          include_total_count: true,
          total_count_primary_key_field: :city
        )

      assert metadata == %Metadata{
               after: encode_cursor(%{city: a2.city}),
               before: nil,
               limit: 2,
               total_count: 3,
               total_count_cap_exceeded: false
             }
    end
  end

  test "when before parameter is erlang term, we do not execute the code", %{} do
    # before and after, are user inputs, we need to make sure that they are
    # handled safely.

    test_pid = self()

    exploit = fn _, _ ->
      send(test_pid, :rce)
      {:cont, []}
    end

    payload =
      exploit
      |> :erlang.term_to_binary()
      |> Base.url_encode64()

    assert_raise(ArgumentError, ~r/^cannot deserialize.+/, fn ->
      payments_by_amount_and_charged_at(:asc, :desc)
      |> Repo.paginate(
        cursor_fields: [amount: :asc, charged_at: :desc, id: :asc],
        before: payload,
        limit: 3
      )
    end)

    refute_receive :rce, 1000, "Remote Code Execution Detected"
  end

  test "per-record cursor generation", %{
    payments: {p1, _p2, _p3, _p4, _p5, _p6, p7, _p8, _p9, _p10, _p11, _p12}
  } do
    assert Paginator.cursor_for_record(p1, charged_at: :asc, id: :asc) ==
             encode_cursor(%{charged_at: p1.charged_at, id: p1.id})

    assert Paginator.cursor_for_record(p7, amount: :asc) == encode_cursor(%{amount: p7.amount})
  end

  test "per-record cursor generation with custom cursor value function", %{
    payments: {p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
  } do
    assert Paginator.cursor_for_record(p1, [charged_at: :asc, id: :asc], fn schema, field ->
             case field do
               :id -> Map.get(schema, :id)
               _ -> "10"
             end
           end) == encode_cursor(%{charged_at: "10", id: p1.id})
  end

  test "sorts on two different directions with before cursor", %{
    payments: {_p1, _p2, _p3, p4, p5, p6, p7, _p8, _p9, _p10, _p11, _p12}
  } do
    %Page{entries: entries, metadata: metadata} =
      payments_by_amount_and_charged_at(:asc, :desc)
      |> Repo.paginate(
        cursor_fields: [amount: :asc, charged_at: :desc, id: :asc],
        before: encode_cursor(%{amount: p7.amount, charged_at: p7.charged_at, id: p7.id}),
        limit: 3
      )

    assert to_ids(entries) == to_ids([p6, p4, p5])

    assert metadata == %Metadata{
             after: encode_cursor(%{amount: p5.amount, charged_at: p5.charged_at, id: p5.id}),
             before: nil,
             limit: 3
           }
  end

  test "sorts on two different directions with after cursor", %{
    payments: {_p1, _p2, _p3, p4, p5, _p6, p7, p8, _p9, _p10, _p11, _p12}
  } do
    %Page{entries: entries, metadata: metadata} =
      payments_by_amount_and_charged_at(:asc, :desc)
      |> Repo.paginate(
        cursor_fields: [amount: :asc, charged_at: :desc, id: :asc],
        after: encode_cursor(%{amount: p4.amount, charged_at: p4.charged_at, id: p4.id}),
        limit: 3
      )

    assert to_ids(entries) == to_ids([p5, p7, p8])

    assert metadata == %Metadata{
             after: encode_cursor(%{amount: p8.amount, charged_at: p8.charged_at, id: p8.id}),
             before: encode_cursor(%{amount: p5.amount, charged_at: p5.charged_at, id: p5.id}),
             limit: 3
           }
  end

  test "sorts on two different directions with before and after cursor", %{
    payments: {_p1, _p2, _p3, p4, p5, p6, p7, p8, _p9, _p10, _p11, _p12}
  } do
    %Page{entries: entries, metadata: metadata} =
      payments_by_amount_and_charged_at(:desc, :asc)
      |> Repo.paginate(
        cursor_fields: [amount: :desc, charged_at: :asc, id: :asc],
        after: encode_cursor(%{amount: p8.amount, charged_at: p8.charged_at, id: p8.id}),
        before: encode_cursor(%{amount: p6.amount, charged_at: p6.charged_at, id: p6.id}),
        limit: 8
      )

    assert to_ids(entries) == to_ids([p7, p5, p4])

    assert metadata == %Metadata{
             after: encode_cursor(%{amount: p4.amount, charged_at: p4.charged_at, id: p4.id}),
             before: encode_cursor(%{amount: p7.amount, charged_at: p7.charged_at, id: p7.id}),
             limit: 8
           }
  end

  test "paginates unions and subqueries including total count", %{
    boats: {b1, b2, b3, b4, b5, b6},
    airplanes: {a1, a2, a3, a4, a5}
  } do
    opts = [cursor_fields: [:year, :name, :type], sort_direction: :asc, limit: 4, include_total_count: true]

    page = airplanes_and_boats_by_year() |> Repo.paginate(opts)

    assert to_uids(page.entries) == to_uids([b1, b2, a1, a2])
    assert page.metadata.after == encode_cursor(%{year: a2.year, name: a2.name, type: a2.type})

    page = airplanes_and_boats_by_year() |> Repo.paginate(opts ++ [after: page.metadata.after])
    assert to_uids(page.entries) == to_uids([a5, b4, b5, a4])
    assert page.metadata.after == encode_cursor(%{year: a4.year, name: a4.name, type: a4.type})

    page = airplanes_and_boats_by_year() |> Repo.paginate(opts ++ [after: page.metadata.after])
    assert to_uids(page.entries) == to_uids([a3, b3, b6])
    assert page.metadata.after == nil
  end

  test "paginate with nullable cursor and ascending order" do
    c = insert(:customer, %{name: "Bob"})

    p1 = insert(:payment, customer: c, charged_at: nil)
    p2 = insert(:payment, customer: c, charged_at: nil)
    p3 = insert(:payment, customer: c, charged_at: days_ago(6))
    p4 = insert(:payment, customer: c, charged_at: days_ago(11))

    query = from(p in Payment, where: p.customer_id == ^c.id, order_by: [:charged_at, :id])
    opts = [cursor_fields: [charged_at: :asc, id: :asc], limit: 2]

    page = Repo.paginate(query, opts)

    assert to_ids(page.entries) == to_ids([p4, p3])

    page = Repo.paginate(query, opts ++ [after: page.metadata.after])

    assert to_ids(page.entries) == to_ids([p1, p2])
  end

  test "paginate with nullable cursor and descending order" do
    c = insert(:customer, %{name: "Bob"})

    p1 = insert(:payment, customer: c, charged_at: nil)
    p2 = insert(:payment, customer: c, charged_at: nil)
    p3 = insert(:payment, customer: c, charged_at: nil)
    p4 = insert(:payment, customer: c, charged_at: days_ago(6))
    p5 = insert(:payment, customer: c, charged_at: days_ago(11))
    p6 = insert(:payment, customer: c, charged_at: nil)

    query = from(p in Payment, where: p.customer_id == ^c.id, order_by: [desc: :charged_at, asc: :id])
    opts = [cursor_fields: [charged_at: :desc, id: :asc], limit: 3]

    page = Repo.paginate(query, opts)

    assert to_ids(page.entries) == to_ids([p1, p2, p3])

    page = Repo.paginate(query, opts ++ [after: page.metadata.after])

    assert to_ids(page.entries) == to_ids([p6, p4, p5])
  end

  defp to_ids(entries), do: Enum.map(entries, & &1.id)

  defp create_customers_and_payments(_context) do
    c1 = insert(:customer, %{name: "Bob"})
    c2 = insert(:customer, %{name: "Alice"})
    c3 = insert(:customer, %{name: "Charlie"})

    a1 = insert(:address, city: "London", customer: c1)
    a2 = insert(:address, city: "New York", customer: c2)
    a3 = insert(:address, city: "Tokyo", customer: c3)

    p1 = insert(:payment, customer: c2, charged_at: days_ago(11))
    p2 = insert(:payment, customer: c2, charged_at: days_ago(6))
    p3 = insert(:payment, customer: c2, charged_at: days_ago(8))
    p4 = insert(:payment, customer: c2, amount: 2, charged_at: days_ago(12))

    p5 = insert(:payment, customer: c1, amount: 3, charged_at: days_ago(13))
    p6 = insert(:payment, customer: c1, amount: 2, charged_at: days_ago(10))
    p7 = insert(:payment, customer: c1, amount: 4, charged_at: days_ago(9))
    p8 = insert(:payment, customer: c1, amount: 5, charged_at: days_ago(4))

    p9 = insert(:payment, customer: c3, charged_at: days_ago(3))
    p10 = insert(:payment, customer: c3, charged_at: days_ago(7))
    p11 = insert(:payment, customer: c3, charged_at: days_ago(2))
    p12 = insert(:payment, customer: c3, charged_at: days_ago(5))

    {:ok,
     customers: {c1, c2, c3},
     addresses: {a1, a2, a3},
     payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}}
  end

  defp to_uids(entries), do: Enum.map(entries, &to_uid/1)
  defp to_uid(%{id: id, entry_type: entry_type}), do: to_uid(id, String.to_atom(entry_type))
  defp to_uid(%Boat{id: id}), do: to_uid(id, :boat)
  defp to_uid(%Airplane{id: id}), do: to_uid(id, :airplane)
  defp to_uid(%{uid: uid}), do: uid
  defp to_uid(id, type \\ :boat) when is_integer(id) do
    case type do
      :boat -> "b" <> Integer.to_string(id)
      :airplane -> "a" <> Integer.to_string(id)
      _ -> id
    end
  end

  defp create_boats_and_airplanes(_context) do
    a1 = insert(:airplane, %{name: "Spitfire", year: 1936})
    a2 = insert(:airplane, %{name: "Mitsubishi Zero", year: 1940})
    a3 = insert(:airplane, %{name: "Yakovlev Yak-3", year: 1944})
    a4 = insert(:airplane, %{name: "Messerschmitt Me 262", year: 1944})
    a5 = insert(:airplane, %{name: "Grumman F6F Hellcat", year: 1942})

    b1 = insert(:boat, %{name: "Black Pearl", year: 1708, type: "galleon", capacity: 250})
    b2 = insert(:boat, %{name: "RMS Titanic", year: 1911, type: "ocean liner", capacity: 3327})
    b3 = insert(:boat, %{name: "Oceania", year: 2003, type: "tanker", capacity: 3166353})
    b4 = insert(:boat, %{name: "HMS Activity", year: 1942, type: "escort carrier", capacity: 10})
    b5 = insert(:boat, %{name: "USS Activity", year: 1942, type: "battleship", capacity: 2500})
    b6 = insert(:boat, %{name: "Severodvinsk", year: 2010, type: "nuclear submarine", capacity: 90})

    {:ok,
      boats: {b1, b2, b3, b4, b5, b6},
      airplanes: {a1, a2, a3, a4, a5}}
  end

  defp create_data(context) do
    {:ok, payments_and_customers} = create_customers_and_payments(context)
    {:ok, boats_and_airplanes} = create_boats_and_airplanes(context)
    {:ok, payments_and_customers ++ boats_and_airplanes}
  end

  defp payments_by_status(status, direction \\ :asc) do
    from(
      p in Payment,
      where: p.status == ^status,
      order_by: [{^direction, p.charged_at}, {^direction, p.id}],
      select: p
    )
  end

  defp payments_by_amount_and_charged_at(amount_direction, charged_at_direction) do
    from(
      p in Payment,
      order_by: [
        {^amount_direction, p.amount},
        {^charged_at_direction, p.charged_at},
        {:asc, p.id}
      ],
      select: p
    )
  end

  defp payments_by_charged_at(direction \\ :asc) do
    from(
      p in Payment,
      order_by: [{^direction, p.charged_at}, {^direction, p.id}],
      select: p
    )
  end

  defp payments_by_customer_name(payment_id_direction \\ :asc, customer_name_direction \\ :asc) do
    from(
      p in Payment,
      as: :payments,
      join: c in assoc(p, :customer),
      as: :customer,
      preload: [customer: c],
      select: p,
      order_by: [
        {^customer_name_direction, c.name},
        {^payment_id_direction, p.id}
      ]
    )
  end

  defp payments_by_address_city(payment_id_direction \\ :asc, address_city_direction \\ :asc) do
    from(
      p in Payment,
      as: :payments,
      join: c in assoc(p, :customer),
      as: :customer,
      join: a in assoc(c, :address),
      as: :address,
      preload: [customer: {c, address: a}],
      select: p,
      order_by: [
        {^address_city_direction, a.city},
        {^payment_id_direction, p.id}
      ]
    )
  end

  defp customer_payments_by_charged_at_and_amount(customer, direction \\ :asc) do
    from(
      p in Payment,
      where: p.customer_id == ^customer.id,
      order_by: [{^direction, p.charged_at}, {^direction, p.amount}, {^direction, p.id}]
    )
  end

  defp boats_struct_query() do
    from(
      b in Boat,
      select: %{
        id: b.id,
        name: b.name,
        type: b.type,
        year: b.year,
        entry_type: fragment("'boat'")
      }
    )
  end

  defp airplanes_struct_query() do
    from(
      a in Airplane,
      select: %{
        id: a.id,
        name: a.name,
        type: a.type,
        year: a.year,
        entry_type: fragment("'airplane'")
      }
    )
  end

  defp airplanes_and_boats_by_year() do
    boats_query = boats_struct_query()

    airplanes_struct_query()
      |> union_all(^boats_query)
      |> subquery()
      |> order_by([:year, :name, :type])
  end

  defp encode_cursor(value) do
    Cursor.encode(value)
  end

  defp encode_legacy_cursor(value) when is_list(value) do
    value
    |> :erlang.term_to_binary()
    |> Base.url_encode64()
  end

  defp days_ago(days) do
    DT.add!(DateTime.utc_now(), -(days * 86400))
  end
end
