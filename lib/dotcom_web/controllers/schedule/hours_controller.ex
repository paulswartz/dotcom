defmodule DotcomWeb.ScheduleController.HoursController do
  @moduledoc "Returns the hours of operation for a given route"

  use DotcomWeb, :controller

  alias DotcomWeb.ControllerHelpers
  alias Routes.Route

  # uses a date URL parameter to set conn.assigns.date
  plug(DotcomWeb.Plugs.Date)

  def hours_of_operation(conn, %{"route" => "Green"}) do
    # Return an empty object.  Only supports specific routes
    json(conn, %{})
  end

  def hours_of_operation(conn, %{"route" => route_id}) do
    do_hours_of_operation(conn, route_id, &Schedules.HoursOfOperation.hours_of_operation/3)
  end

  def hours_of_operation_by_stop(conn, %{"route" => "Green"}) do
    # Return an empty object.  Only supports specific routes
    json(conn, %{})
  end

  def hours_of_operation_by_stop(conn, %{"route" => route_id}) do
    do_hours_of_operation(
      conn,
      route_id,
      &Schedules.HoursOfOperation.hours_of_operation_by_stop/3
    )
  end

  defp do_hours_of_operation(conn, route_id, hours_fn) do
    with %Route{description: description, id: id} <- Routes.Repo.get(route_id) do
      hours_of_operation =
        hours_fn.(
          id,
          conn.assigns.date,
          description
        )

      json(conn, hours_of_operation)
    else
      error ->
        ControllerHelpers.return_error(conn, :internal_server_error, inspect(error))
    end
  end
end
