defmodule Paginator.Factory do
  use ExMachina.Ecto, repo: Paginator.Repo

  alias Paginator.{Customer, Address, Payment, Boat, Airplane}

  def customer_factory do
    %Customer{
      name: "Bob",
      active: true
    }
  end

  def address_factory do
    %Address{
      city: "City name",
      customer: build(:customer)
    }
  end

  def payment_factory do
    %Payment{
      description: "Skittles",
      charged_at: DateTime.utc_now(),
      # +10 so it doesn't mess with low amounts we want to order on.
      amount: :rand.uniform(100) + 10,
      status: "success",
      customer: build(:customer)
    }
  end

  def boat_factory do
    %Boat{
      name: "My Boat",
      year: 2019,
      type: "Sloop",
      capacity: 1
    }
  end

  def airplane_factory do
    %Airplane{
      name: "Spitfire",
      year: 1936,
      type: "Fighter",
      seats: 1
    }
  end
end
