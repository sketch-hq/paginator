defmodule Paginator.Boat do
  use Ecto.Schema

  schema "boats" do
    field(:name, :string)
    field(:year, :integer)
    field(:type, :string)
    field(:capacity, :integer)

    timestamps()
  end
end
