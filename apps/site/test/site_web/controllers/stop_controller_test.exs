defmodule SiteWeb.StopControllerTest do
  use SiteWeb.ConnCase
  alias Routes.Route
  alias SiteWeb.StopController
  alias Stops.Stop
  alias Util.Breadcrumb
  import Mock

  test "renders react content server-side", %{conn: conn} do
    assert [{"div", _, content}] =
             conn
             |> get(stop_path(conn, :show, "place-sstat"))
             |> html_response(200)
             |> Floki.find("#react-root")

    assert [_ | _] = content
  end

  test "redirects to subway stops on index", %{conn: conn} do
    conn = conn |> get(stop_path(conn, :index))
    assert redirected_to(conn) == stop_path(conn, :show, :subway)
  end

  test "shows stations by mode", %{conn: conn} do
    conn =
      conn
      |> get(stop_path(conn, :show, :subway))

    response = html_response(conn, 200)

    for line <- ["Green", "Red", "Blue", "Orange", "Mattapan"] do
      assert response =~ line
    end
  end

  test "assigns stop_info for each mode", %{conn: conn} do
    for mode <- [:subway, :ferry, "commuter-rail"] do
      conn =
        conn
        |> get(stop_path(conn, :show, mode))

      assert conn.assigns.stop_info
    end
  end

  test "redirects stations with slashes to the right URL", %{conn: conn} do
    conn =
      conn
      |> get("/stops/Four%20Corners%20/%20Geneva")

    assert redirected_to(conn) == stop_path(conn, :show, "Four Corners / Geneva")
  end

  test "assigns routes for this stop", %{conn: conn} do
    conn =
      conn
      |> get(stop_path(conn, :show, "place-sstat"))

    assert conn.assigns.routes
  end

  test "assigns ferry routes", %{conn: conn} do
    with_mock(Laboratory, [], enabled?: fn _, :stops_redesign -> false end) do
      conn =
        conn
        |> get(stop_path(conn, :show, "Boat-Charlestown"))

      assert [ferry] = conn.assigns.routes
      assert %{group_name: :ferry, routes: [%{route: %{id: "Boat-F4"}}]} = ferry
    end
  end

  test "assigns the zone number for the current stop", %{conn: conn} do
    conn =
      conn
      |> get(stop_path(conn, :show, "place-WML-0442"))

    assert conn.assigns.zone_number == "8"
  end

  test "sets a custom meta description for stops", %{conn: conn} do
    conn =
      conn
      |> get(stop_path(conn, :show, "place-sstat"))

    assert conn.assigns.meta_description
  end

  test "redirects to a parent stop page for a child stop", %{conn: conn} do
    conn =
      conn
      |> get(stop_path(conn, :show, 70_130))

    assert redirected_to(conn) == stop_path(conn, :show, "place-harvd")
  end

  test "404s for an unknown stop", %{conn: conn} do
    conn =
      conn
      |> get(stop_path(conn, :show, "unknown"))

    assert Map.fetch!(conn, :status) == 404
  end

  describe "breadcrumbs/2" do
    test "returns station breadcrumbs if the stop is served by more than buses" do
      stop = %Stop{name: "Name", station?: true}
      routes = [%Route{id: "CR-Lowell", type: 2}]

      assert StopController.breadcrumbs(stop, routes) == [
               %Breadcrumb{text: "Stations", url: "/stops/commuter-rail"},
               %Breadcrumb{text: "Name", url: ""}
             ]
    end

    test "returns simple breadcrumb if the stop is served by only buses" do
      stop = %Stop{name: "Dudley Station"}
      routes = [%Route{id: "28", type: 3}]

      assert StopController.breadcrumbs(stop, routes) == [
               %Breadcrumb{text: "Dudley Station", url: ""}
             ]
    end

    test "returns simple breadcrumb if we have no route info for the stop" do
      stop = %Stop{name: "Name", station?: true}
      assert StopController.breadcrumbs(stop, []) == [%Breadcrumb{text: "Name", url: ""}]
    end
  end

  describe "api" do
    test "returns json with departure data", %{conn: conn} do
      path = stop_path(conn, :api, id: "place-sstat")
      assert path == "/stops/api?id=place-sstat"

      response =
        conn
        |> get(path)
        |> json_response(200)

      assert is_list(response)
      refute Enum.empty?(response)

      for item <- response do
        assert %{"group_name" => _, "routes" => _} = item
      end
    end
  end

  describe "show/2" do
    test "should set the title and meta description of the page", %{conn: conn} do
      with_mock(Laboratory, [], enabled?: fn _, :stops_redesign -> true end) do
        conn =
          conn
          |> get(stop_path(conn, :show, "place-wondl"))

        [_stations, station_name] = conn.assigns.breadcrumbs

        assert "Wonderland" = station_name.text

        assert "Station serving MBTA Subway and Bus lines at 1300 North Shore Rd, Revere, MA 02151." =
                 conn.assigns.meta_description
      end
    end
  end
end
