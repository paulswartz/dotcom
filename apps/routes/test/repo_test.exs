defmodule Routes.RepoTest do
  use ExUnit.Case, async: true
  alias Routes.{Repo, Route}

  describe "all/0" do
    test "returns something" do
      assert Repo.all() != []
    end

    test "parses the data into Route structs" do
      assert Repo.all() |> List.first() == %Route{
               id: "Red",
               type: 1,
               name: "Red Line",
               long_name: "Red Line",
               color: "DA291C",
               direction_names: %{0 => "Southbound", 1 => "Northbound"},
               direction_destinations: %{0 => "Ashmont/Braintree", 1 => "Alewife"},
               description: :rapid_transit
             }
    end

    test "parses a long name for the Green Line" do
      [route] =
        Repo.all()
        |> Enum.filter(&(&1.id == "Green-B"))

      assert route == %Route{
               id: "Green-B",
               type: 0,
               name: "Green Line B",
               long_name: "Green Line B",
               color: "00843D",
               direction_names: %{0 => "Westbound", 1 => "Eastbound"},
               direction_destinations: %{0 => "Boston College", 1 => "Park Street"},
               description: :rapid_transit
             }
    end

    test "parses a short name instead of a long one" do
      [route] =
        Repo.all()
        |> Enum.filter(&(&1.name == "SL1"))

      assert route == %Route{
               id: "741",
               type: 3,
               name: "SL1",
               long_name: "Logan Airport - South Station",
               color: "7C878E",
               direction_destinations: %{0 => "Logan Airport", 1 => "South Station"},
               description: :key_bus_route
             }
    end

    test "parses a short_name if there's no long name" do
      [route] =
        Repo.all()
        |> Enum.filter(&(&1.name == "23"))

      assert route == %Route{
               id: "23",
               type: 3,
               name: "23",
               long_name: "Ashmont - Ruggles via Washington Street",
               color: "FFC72C",
               direction_destinations: %{0 => "Ashmont", 1 => "Ruggles"},
               description: :key_bus_route
             }
    end

    test "filters out 'hidden' routes'" do
      all = Repo.all()
      assert all |> Enum.filter(fn route -> route.name == "24/27" end) == []
    end
  end

  describe "by_type/1" do
    test "only returns routes of a given type" do
      one = Repo.by_type(1)
      assert one |> Enum.all?(fn route -> route.type == 1 end)
      assert one != []
      assert one == Repo.by_type([1])
    end

    test "filtering by a list keeps the routes in their global order" do
      assert Repo.by_type([0, 1, 2, 3, 4]) == Repo.all()
    end
  end

  describe "get/1" do
    test "returns a single route" do
      assert %Route{
               id: "Red",
               name: "Red Line",
               type: 1
             } = Repo.get("Red")
    end

    test "returns nil for an unknown route" do
      refute Repo.get("_unknown_route")
    end

    test "returns a hidden route" do
      assert %Route{id: "746"} = Repo.get("746")
    end
  end

  test "key bus routes are tagged" do
    assert %Route{description: :key_bus_route} = Repo.get("1")
    assert %Route{description: :key_bus_route} = Repo.get("741")
    assert %Route{description: :local_bus} = Repo.get("47")
  end

  describe "by_stop/1" do
    test "returns stops from different lines" do
      # Kenmore Square
      route_ids = Repo.by_stop("place-kencl") |> Enum.map(& &1.id)
      assert "Green-B" in route_ids
      assert "19" in route_ids
    end

    test "can specify type as param" do
      # Kenmore Square
      assert "19" in (Repo.by_stop("place-kencl", type: 3) |> Enum.map(& &1.id))
    end

    test "returns empty list if no routes of that type serve that stop" do
      assert [] = Repo.by_stop("place-bmmnl", type: 0)
    end

    test "returns no routes on nonexistant station" do
      assert [] = Repo.by_stop("thisstopdoesntexist")
    end
  end

  describe "by_stop_and_direction/2" do
    test "fetching routes for the same stop, but different direction" do
      kenmore_outbound_routes = Repo.by_stop_and_direction("place-kencl", 0)
      kenmore_inbound_routes = Repo.by_stop_and_direction("place-kencl", 1)

      refute Enum.any?(kenmore_outbound_routes, &(&1.id == "9"))
      assert Enum.any?(kenmore_inbound_routes, &(&1.id == "9"))
    end
  end

  describe "route_hidden?/1" do
    test "Returns true for hidden routes" do
      hidden_routes = [
        "746",
        "2427",
        "3233",
        "3738",
        "4050",
        "627",
        "725",
        "8993",
        "116117",
        "214216",
        "441442",
        "9701",
        "9702",
        "9703",
        "Logan-Airport",
        "CapeFlyer"
      ]

      for route_id <- hidden_routes do
        assert Repo.route_hidden?(%{id: route_id})
      end
    end

    test "Returns false for non hidden routes" do
      visible_routes = ["SL1", "66", "1", "742"]

      for route_id <- visible_routes do
        refute Repo.route_hidden?(%{id: route_id})
      end
    end
  end

  describe "handle_response/1" do
    test "parses routes" do
      response = %JsonApi{
        data: [
          %JsonApi.Item{
            attributes: %{
              "description" => "Local Bus",
              "direction_names" => ["Outbound", "Inbound"],
              "direction_destinations" => ["Start", "End"],
              "long_name" => "",
              "short_name" => "16",
              "sort_order" => 1600,
              "type" => 3
            },
            id: "16",
            relationships: %{},
            type: "route"
          },
          %JsonApi.Item{
            attributes: %{
              "description" => "Local Bus",
              "direction_names" => ["Outbound", "Inbound"],
              "direction_destinations" => ["Start", "End"],
              "long_name" => "",
              "short_name" => "36",
              "sort_order" => 3600,
              "type" => 3
            },
            id: "36",
            relationships: %{},
            type: "route"
          }
        ],
        links: %{}
      }

      assert {:ok, [%Route{id: "16"}, %Route{id: "36"}]} = Repo.handle_response(response)
    end

    test "removes hidden routes" do
      response = %JsonApi{
        data: [
          %JsonApi.Item{
            attributes: %{
              "description" => "Local Bus",
              "direction_names" => ["Outbound", "Inbound"],
              "direction_destinations" => ["Start", "End"],
              "long_name" => "",
              "short_name" => "36",
              "sort_order" => 3600,
              "type" => 3
            },
            id: "36",
            relationships: %{},
            type: "route"
          },
          %JsonApi.Item{
            attributes: %{
              "description" => "Limited Service",
              "direction_names" => ["Outbound", "Inbound"],
              "direction_destinations" => ["Start", "End"],
              "long_name" => "",
              "short_name" => "9701",
              "sort_order" => 970_100,
              "type" => 3
            },
            id: "9701",
            relationships: %{},
            type: "route"
          }
        ],
        links: %{}
      }

      assert {:ok, [%Route{id: "36"}]} = Repo.handle_response(response)
    end

    test "passes errors through" do
      error = {:error, %HTTPoison.Error{id: nil, reason: :timeout}}
      assert Repo.handle_response(error) == error
    end
  end

  describe "get_shapes/2" do
    test "Get valid response for bus route" do
      shapes = Repo.get_shapes("9", direction_id: 1)
      shape = List.first(shapes)

      assert Enum.count(shapes) >= 2
      assert is_binary(shape.id)
      assert Enum.count(shape.stop_ids) >= 26
    end

    test "get different number of shapes from same route depending on filtering" do
      all_shapes = Repo.get_shapes("100", [direction_id: 1], false)
      priority_shapes = Repo.get_shapes("100", direction_id: 1)

      refute Enum.count(all_shapes) == Enum.count(priority_shapes)
    end
  end

  describe "get_shape/1" do
    shape =
      "903_0018"
      |> Repo.get_shape()
      |> List.first()

    assert shape.id == "903_0018"
  end

  describe "green_line" do
    green_line = Repo.green_line()
    assert green_line.id == "Green"
    assert green_line.name == "Green Line"
  end
end
