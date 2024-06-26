defmodule FoodTruckDatabase do
  use GenServer

  @url "https://data.sfgov.org/api/views/rqzj-sfat/rows.json"
  @table_name :food_trucks


  # A genserver is used here simply to demonstrate how to use a GenServer, but it is not necessary.
  # Init could happen in start/2 @ lib/food_truck/application.ex, and the functions could be called
  # directly.

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_food_trucks do
    GenServer.call(__MODULE__, :get_food_trucks)
  end

  # An ETS table is used to store the food truck data. This is a simple way to store the data in memory and it
  # allows for fast concurrent lookups. The data is loaded from the API when the GenServer is started and
  # refreshed every 24 hours.

  @impl true
  def init(_) do
    :ets.new(@table_name, [:set, :public, :named_table, {:read_concurrency, true}, {:write_concurrency, true}])
    send(self(), :load_data)
    refresh_every_24_hours()
    {:ok, %{loaded: false}}
  end

  @impl true
  def handle_info(:load_data, state) do
    case update_data() do
      :ok ->
        IO.puts("Data loaded successfully")
        {:noreply, %{state | loaded: true}}
      {:error, reason} ->
        IO.puts("Error loading data: #{reason}")
        Process.send_after(self(), :load_data, 60_000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:refresh_data, state) do
    Task.start(fn -> update_data() end)
    refresh_every_24_hours()
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_food_trucks, _from, state) do
    trucks = :ets.foldl(fn {_id, entry}, acc -> [entry | acc] end, [], @table_name)
    {:reply, trucks, state}
  end

  defp refresh_every_24_hours() do
    Process.send_after(self(), :refresh_data, 24 * 60 * 60 * 1000)
  end

  defp update_data do
    case fetch_data() do
      {:ok, new_data} ->
        update_ets_table(new_data)
        IO.puts("Data updated successfully")
        :ok
      {:error, reason} ->
        IO.puts("Error updating data: #{reason}")
        {:error, reason}
    end
  end

  defp fetch_data do
    with {:ok, %{body: body}} <- HTTPoison.get(@url),
         {:ok, json_data} <- Jason.decode(body) do
      columns = json_data["meta"]["view"]["columns"] |> Enum.map(& &1["name"])
      data = json_data["data"] |> Enum.map(fn row -> Enum.zip(columns, row) |> Enum.into(%{}) end)
      {:ok, data}
    else
      {:error, %HTTPoison.Error{reason: reason}} -> {:error, "HTTP Error: #{reason}"}
      {:error, %Jason.DecodeError{}} -> {:error, "JSON Decode Error"}
      _ -> {:error, "Unknown Error"}
    end
  end

  defp update_ets_table(new_data) do
    existing_records = :ets.tab2list(@table_name)

    existing_ids = MapSet.new(existing_records, fn {id, _} -> id end)
    {updated, added} =
      Enum.reduce(new_data, {0, 0}, fn record, {updated, added} ->
        case record["id"] do
          nil ->
            IO.puts("Warning: Found record without id: #{inspect(record)}")
            {updated, added}
          id ->
            if MapSet.member?(existing_ids, id) do
              :ets.insert(@table_name, {id, record})
              {updated + 1, added}
            else
              :ets.insert(@table_name, {id, record})
              {updated, added + 1}
            end
        end
      end)

    new_ids = MapSet.new(new_data, & &1["id"])
    removed = Enum.reduce(existing_ids, 0, fn id, acc ->
      if not MapSet.member?(new_ids, id) do
        :ets.delete(@table_name, id)
        acc + 1
      else
        acc
      end
    end)

    total_records = :ets.info(@table_name, :size)
    IO.puts("Total records: #{total_records}, Updated #{updated} records, removed #{removed} old records, added #{added} new records")
  end
end
