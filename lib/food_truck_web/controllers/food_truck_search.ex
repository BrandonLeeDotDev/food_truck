defmodule FoodTruckWeb.FoodTruckController do
  use FoodTruckWeb, :controller

  # Render page for get request
  def index(conn, params) do
    case search_trucks(params) do
      [] ->
        conn
        |> put_flash(:info, "No food trucks found")
        |> render(:index, trucks: [])

      trucks ->
        conn
        |> render(:index, trucks: trucks)
    end
  end

  # Provide a JSON response for post request
  def search(conn, params) do
    case search_trucks(params) do
      [] ->
        conn
        |> put_status(:not_found)
        |> json(%{message: "No food trucks found", trucks: []})

      trucks ->
        conn
        |> json(%{trucks: trucks})
    end
  end

  def search_trucks(params) do
    trucks = FoodTruckDatabase.get_food_trucks()

    trucks
    |> filter_by_status()
    |> filter_by_distance(params)
    |> filter_by_name(params)
    |> filter_by_food_items(params)
    |> rand_results(params)
  end

  # Status could be passed as a query parameter to filter by status... but it's not. For now, we'll just assume that
  # filtering by "approved" or "requested" is sufficient. We'll also filter out trucks with a latitude or longitude of 0.
  # Of course these decisions should be made in consultation with interested parties / stakeholders.
  def filter_by_status(trucks) do
    Enum.filter(trucks, fn truck ->
      status = String.downcase(truck["Status"] || "")

      (String.contains?(status, "approved") || String.contains?(status, "requested")) &&
        truck["Latitude"] != "0" && truck["Longitude"] != "0"
    end)
  end

  def filter_by_distance(trucks, %{"latitude" => lat, "longitude" => lon} = params)
      when lat != "" and lon != "" do
    case {to_float(lat), to_float(lon)} do
      {lat, lon} when is_float(lat) and is_float(lon) ->
        distance =
          case params do
            %{"distance" => d} when d != "" ->
              {dist, _} = Float.parse(d)
              dist

            # default distance
            _ ->
              10000.0
          end

        get_food_trucks_by_distance(trucks, lat, lon, distance)

      _ ->
        # Return all trucks if input is invalid
        trucks
    end
  end

  def filter_by_distance(trucks, _), do: trucks

  def filter_by_name(trucks, %{"name" => name}) when name != "" do
    Enum.filter(trucks, fn truck ->
      String.contains?(String.downcase(truck["Applicant"] || ""), String.downcase(name))
    end)
  end

  def filter_by_name(trucks, _), do: trucks

  def filter_by_food_items(trucks, %{"food_items" => food_items}) when food_items != "" do
    or_groups = String.split(food_items, ",", trim: true)
                |> Enum.map(&String.trim/1)

    Enum.filter(trucks, fn truck ->
      truck_items = String.downcase(truck["FoodItems"] || "")

      Enum.any?(or_groups, fn or_group ->
        and_items = String.split(or_group, "&", trim: true)
                    |> Enum.map(&String.trim/1)
                    |> Enum.map(&String.downcase/1)

        Enum.all?(and_items, &String.contains?(truck_items, &1))
      end)
    end)
  end
  def filter_by_food_items(trucks, _), do: trucks

  def rand_results(trucks, %{"rand_results" => food_items}) when food_items == "1" do
    # We shuffle to provide a more interesting experience for the user as the premis is "They are also a team that loves
    # variety, so they also like to discover new places to eat."
    Enum.shuffle(trucks)
  end

  def rand_results(trucks, _), do: trucks

  def get_food_trucks_by_distance(trucks, lat, lon, distance) do
    IO.puts("Searching for trucks within #{distance} mi of (#{lat}, #{lon})")

    trucks
    |> Enum.map(fn %{"Latitude" => truck_lat, "Longitude" => truck_lon} = truck ->
      [lat1, lon1, lat2, lon2] =
        [lat, lon, truck_lat, truck_lon]
        |> Enum.map(&to_float/1)

      # Geocalc.distance_between returns haversine distance in meters, so we divide by 1000 to get kilometers
      # and then divide by 1.609 to get miles
      dist =
        (Geocalc.distance_between([lat1, lon1], [lat2, lon2]) / 1000.0 / 1.609)
        |> Float.round(2)

      {dist, truck}
    end)
    |> Enum.filter(fn {dist, _truck} ->
      float_compare(dist, distance, 0.1) || dist < distance
    end)
    |> Enum.map(fn {dist, truck} ->
      Map.put(truck, "distance", Float.round(dist, 2))
    end)
  end

  # Convert various types to float
  def to_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> nil
    end
  end

  def to_float(value) when is_float(value), do: value
  def to_float(value) when is_number(value), do: value * 1.0
  def to_float(_), do: nil

  def float_compare(a, b, epsilon) do
    abs(a - b) < epsilon
  end
end
