defmodule FoodTruckWeb.FoodTruckControllerTest do
  use ExUnit.Case, async: false
  alias FoodTruckWeb.FoodTruckController

  @sample_trucks [
    %{
      "Applicant" => "Tasty Truck",
      "Status" => "APPROVED",
      "Latitude" => "37.7749",
      "Longitude" => "-122.4194",
      "FoodItems" => "Tacos: Burritos: Quesadillas"
    },
    %{
      "Applicant" => "Yummy Van",
      "Status" => "REQUESTED",
      "Latitude" => "37.7750",
      "Longitude" => "-122.4195",
      "FoodItems" => "Pizza: Pasta: Calzones"
    },
    %{
      "Applicant" => "Taco Time",
      "Status" => "APPROVED",
      "Latitude" => "37.7751",
      "Longitude" => "-122.4196",
      "FoodItems" => "Tacos: Burritos: Nachos"
    },
    %{
      "Applicant" => "Pizza Paradise",
      "Status" => "APPROVED",
      "Latitude" => "37.7752",
      "Longitude" => "-122.4197",
      "FoodItems" => "Pizza: Calzones: Garlic Bread"
    },
    %{
      "Applicant" => "Burger Bonanza",
      "Status" => "REQUESTED",
      "Latitude" => "37.7753",
      "Longitude" => "-122.4198",
      "FoodItems" => "Burgers: Fries: Milkshakes"
    },
    %{
      "Applicant" => "Tasty Tacos",
      "Status" => "APPROVED",
      "Latitude" => "37.7754",
      "Longitude" => "-122.4199",
      "FoodItems" => "Tacos: Quesadillas: Enchiladas"
    }
  ]

  setup do
    while_not_populated()

    :ets.delete_all_objects(:food_trucks)

    Enum.each(@sample_trucks, fn truck ->
      :ets.insert(:food_trucks, {truck["Applicant"], truck})
    end)

    :ok
  end

  def while_not_populated do
    if !(:ets.info(:food_trucks)[:size] == 6) do
      IO.puts("Waiting for food trucks to be loaded...")

      if !(:ets.info(:food_trucks)[:size] > 1) do
        Process.sleep(2000)
        while_not_populated()
      end
    end
  end

  describe "filter_by_status/1" do
    test "filters out trucks with invalid status or coordinates" do
      filtered = FoodTruckController.filter_by_status(@sample_trucks)
      assert length(filtered) == 6
      assert Enum.all?(filtered, &(&1["Status"] in ["APPROVED", "REQUESTED"]))
      assert Enum.all?(filtered, &(&1["Latitude"] != "0" and &1["Longitude"] != "0"))
    end

    test "handles empty list" do
      assert FoodTruckController.filter_by_status([]) == []
    end
  end

  describe "filter_by_name/2" do
    test "filters trucks by name (case insensitive)" do
      filtered = FoodTruckController.filter_by_name(@sample_trucks, %{"name" => "tasty"})
      assert length(filtered) == 2
      assert Enum.map(filtered, & &1["Applicant"]) == ["Tasty Truck", "Tasty Tacos"]
    end

    test "returns all trucks when no name is provided" do
      filtered = FoodTruckController.filter_by_name(@sample_trucks, %{})
      assert length(filtered) == 6
    end

    test "returns empty list when no matches" do
      filtered = FoodTruckController.filter_by_name(@sample_trucks, %{"name" => "NonExistent"})
      assert filtered == []
    end
  end

  describe "filter_by_food_items/2" do
    test "filters trucks by single food item" do
      filtered =
        FoodTruckController.filter_by_food_items(@sample_trucks, %{"food_items" => "Tacos"})

      assert length(filtered) == 3
      assert Enum.all?(filtered, &String.contains?(&1["FoodItems"], "Tacos"))
    end

    test "filters trucks by multiple food items with OR condition" do
      filtered =
        FoodTruckController.filter_by_food_items(@sample_trucks, %{"food_items" => "Tacos, Pizza"})

      assert length(filtered) == 5

      assert Enum.all?(filtered, fn truck ->
               String.contains?(truck["FoodItems"], "Tacos") or
                 String.contains?(truck["FoodItems"], "Pizza")
             end)
    end

    test "filters trucks by multiple food items with AND condition" do
      filtered =
        FoodTruckController.filter_by_food_items(@sample_trucks, %{
          "food_items" => "Tacos & Burritos"
        })

      assert length(filtered) == 2

      assert Enum.all?(filtered, fn truck ->
               String.contains?(truck["FoodItems"], "Tacos") and
                 String.contains?(truck["FoodItems"], "Burritos")
             end)
    end

    test "filters trucks with combined AND and OR conditions" do
      filtered =
        FoodTruckController.filter_by_food_items(@sample_trucks, %{
          "food_items" => "Tacos & Burritos, Pizza & Calzones"
        })

      assert length(filtered) == 4

      assert Enum.all?(filtered, fn truck ->
               (String.contains?(truck["FoodItems"], "Tacos") and
                  String.contains?(truck["FoodItems"], "Burritos")) or
                 (String.contains?(truck["FoodItems"], "Pizza") and
                    String.contains?(truck["FoodItems"], "Calzones"))
             end)
    end

    test "returns different results for AND vs OR" do
      and_filtered =
        FoodTruckController.filter_by_food_items(@sample_trucks, %{
          "food_items" => "Tacos & Chicken"
        })

      or_filtered =
        FoodTruckController.filter_by_food_items(@sample_trucks, %{
          "food_items" => "Tacos, Chicken"
        })

      assert and_filtered != or_filtered
      assert length(and_filtered) < length(or_filtered)
    end

    test "returns all trucks when no food items are specified" do
      filtered = FoodTruckController.filter_by_food_items(@sample_trucks, %{})
      assert length(filtered) == 6
    end
  end

  describe "rand_results/2" do
    test "shuffles the results when rand_results is 1" do
      shuffled = FoodTruckController.rand_results(@sample_trucks, %{"rand_results" => "1"})
      assert length(shuffled) == 6
      assert shuffled != @sample_trucks
    end

    test "does not shuffle the results when rand_results is not 1" do
      not_shuffled = FoodTruckController.rand_results(@sample_trucks, %{})
      assert not_shuffled == @sample_trucks
    end

    test "handles empty list" do
      assert FoodTruckController.rand_results([], %{"rand_results" => "1"}) == []
    end
  end

  describe "get_food_trucks_by_distance/4" do
    test "filters and sorts trucks by distance" do
      lat = 37.7749
      lon = -122.4194
      distance = 10.0
      result = FoodTruckController.get_food_trucks_by_distance(@sample_trucks, lat, lon, distance)

      assert length(result) == 6
      assert Enum.all?(result, &Map.has_key?(&1, "distance"))
      assert Enum.sort_by(result, & &1["distance"]) == result
    end

    test "returns empty list when no trucks within distance" do
      lat = 0
      lon = 0
      distance = 1.0
      result = FoodTruckController.get_food_trucks_by_distance(@sample_trucks, lat, lon, distance)

      assert result == []
    end
  end

  describe "search_trucks/1" do
    test "applies all filters" do
      params = %{
        "latitude" => "37.7749",
        "longitude" => "-122.4194",
        "distance" => "10",
        "name" => "Tasty",
        "food_items" => "Tacos",
        "rand_results" => "1"
      }

      result = FoodTruckController.search_trucks(params)

      assert length(result) == 2
      assert Enum.all?(result, &(&1["Applicant"] =~ "Tasty"))
      assert Enum.all?(result, &(&1["FoodItems"] =~ "Tacos"))
      assert Enum.all?(result, &Map.has_key?(&1, "distance"))
    end

    test "handles empty params" do
      result = FoodTruckController.search_trucks(%{})
      # Excludes the EXPIRED status truck
      assert length(result) == 6
    end

    test "handles invalid latitude/longitude" do
      params = %{"latitude" => "invalid", "longitude" => "invalid"}
      result = FoodTruckController.search_trucks(params)
      # Excludes the EXPIRED status truck
      assert length(result) == 6
    end
  end

  describe "to_float/1" do
    test "converts string to float" do
      assert FoodTruckController.to_float("3.14") == 3.14
    end

    test "converts integer to float" do
      assert FoodTruckController.to_float(3) == 3.0
    end

    test "returns float as is" do
      assert FoodTruckController.to_float(3.14) == 3.14
    end

    test "handles invalid input" do
      assert FoodTruckController.to_float("invalid") == nil
    end
  end

  describe "float_compare/3" do
    test "compares floats with epsilon" do
      assert FoodTruckController.float_compare(3.14, 3.15, 0.02)
      refute FoodTruckController.float_compare(3.14, 3.15, 0.001)
    end

    test "handles edge cases" do
      assert FoodTruckController.float_compare(0, 0.0000001, 0.001)
      refute FoodTruckController.float_compare(0, 0.1, 0.001)
    end
  end
end
