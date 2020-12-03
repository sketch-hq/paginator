defmodule Paginator.Airplane do
  use Ecto.Schema

  schema "airplanes" do
    field(:name, :string)
    field(:year, :integer)
    field(:type, :string)
    field(:seats, :integer)

    timestamps()
  end
end
