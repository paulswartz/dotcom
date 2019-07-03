defmodule PredictedSchedule do
  @moduledoc """
  Wraps information about a Predicted Schedule

  * schedule: The schedule for this trip (optional)
  * prediction: The prediction for this trip (optional)
  """
  alias Schedules.Schedule
  alias Predictions.Prediction

  defstruct schedule: nil,
            prediction: nil

  @type t :: %__MODULE__{
          schedule: Schedule.t() | nil,
          prediction: Prediction.t() | nil
        }

  def get(route_id, stop_id, opts \\ []) do
    schedules_fn = &Schedules.Repo.by_route_ids/2
    now = Keyword.get(opts, :now)
    direction_id = Keyword.get(opts, :direction_id)
    sort_fn = Keyword.get(opts, :sort_fn, &sort_predicted_schedules/1)

    schedules =
      [route_id]
      |> schedules_fn.(
        stop_ids: stop_id,
        min_time: now,
        direction_id: direction_id
      )

    [route: route_id, stop: stop_id, min_time: now, direction_id: direction_id]
    |> Predictions.Repo.all()
    |> PredictedSchedule.group(schedules, sort_fn: sort_fn)
    |> case do
      [_ | _] = ps ->
        ps

      [] ->
        # if there are no schedules left for today, get schedules for tomorrow
        PredictedSchedule.group(
          [],
          schedules_fn.(
            [route_id],
            stop_ids: stop_id,
            direction_id: direction_id,
            date: Util.tomorrow_date(now)
          ),
          sort_fn: sort_fn
        )
    end
    |> Enum.reject(&PredictedSchedule.last_stop?(&1) || PredictedSchedule.time(&1) == nil)
  end

  @doc """
  The given predictions and schedules will be merged together according to
  stop_id and trip_id to create PredictedSchedules. The final result is a sorted list of
  PredictedSchedules where the `schedule` and `prediction` share a trip_id.
  Either the `schedule` or `prediction` may be nil, but not both.
  """
  @spec group([Prediction.t()], [Schedule.t()], Keyword.t()) :: [PredictedSchedule.t()]
  def group(predictions, schedules, opts \\ []) do
    map = Map.new(schedules, fn schedule ->
      key = group_key(schedule)
      {key, %PredictedSchedule{schedule: schedule}}
    end)
    map = Enum.reduce(predictions, map, fn prediction, map ->
      key = group_key(prediction)
      new_value =
        case map do
          %{^key => existing} ->
            %{existing | prediction: prediction}
        _ ->
            %PredictedSchedule{prediction: prediction}
        end
      Map.put(map, key, new_value)
    end)

    sort_fn = Keyword.get(opts, :sort_fn, &sort_predicted_schedules/1)

    map
    |> Map.values()
    |> Enum.sort_by(sort_fn)
  end

  @spec group_key(Schedule.t() | Prediction.t()) :: {String.t(), String.t(), non_neg_integer}
  defp group_key(%{trip: %{}} = ps) do
    {ps.trip.id, ps.stop.id, ps.stop_sequence}
  end

  defp group_key(ps) do
    {ps.id, ps.stop.id, ps.stop_sequence}
  end

  @doc """
  Returns the stop for a given PredictedSchedule
  """
  @spec stop(PredictedSchedule.t()) :: Stops.Stop.t()
  def stop(%PredictedSchedule{schedule: %Schedule{stop: stop}}), do: stop
  def stop(%PredictedSchedule{prediction: %Prediction{stop: stop}}), do: stop

  @doc """
  Returns the route for a given PredictedSchedule.
  """
  @spec route(PredictedSchedule.t()) :: Routes.Route.t()
  def route(%PredictedSchedule{schedule: %Schedule{route: route}}), do: route
  def route(%PredictedSchedule{prediction: %Prediction{route: route}}), do: route

  @doc """
  Returns the trip for a given PredictedSchedule.
  """
  @spec trip(PredictedSchedule.t()) :: Schedules.Trip.t() | nil
  def trip(%PredictedSchedule{schedule: %Schedule{trip: trip}}), do: trip
  def trip(%PredictedSchedule{prediction: %Prediction{trip: trip}}), do: trip

  @doc """
  Returns the direction ID for a given PredictedSchedule
  """
  @spec direction_id(PredictedSchedule.t()) :: 0 | 1
  def direction_id(%PredictedSchedule{prediction: %Prediction{} = prediction}) do
    prediction.direction_id
  end

  def direction_id(%PredictedSchedule{schedule: %Schedule{trip: trip}}) do
    trip.direction_id
  end

  @doc """
  Determines if the given PredictedSchedule has a schedule
  """
  @spec has_schedule?(PredictedSchedule.t()) :: boolean
  def has_schedule?(%PredictedSchedule{schedule: nil}), do: false
  def has_schedule?(%PredictedSchedule{}), do: true

  @doc """
  Determines if the given PredictedSchedule has a prediction
  """
  @spec has_prediction?(PredictedSchedule.t()) :: boolean
  def has_prediction?(%PredictedSchedule{prediction: nil}), do: false
  def has_prediction?(%PredictedSchedule{}), do: true

  @doc """
  Returns a time value for the given PredictedSchedule. Returned value can be either a scheduled time
  or a predicted time. **Predicted Times are preferred**
  """
  @spec time(PredictedSchedule.t()) :: DateTime.t() | nil
  def time(%PredictedSchedule{prediction: %Prediction{time: time}}) when not is_nil(time) do
    time
  end

  def time(%PredictedSchedule{schedule: %Schedule{time: time}}) do
    time
  end

  def time(%PredictedSchedule{}) do
    # this falls through when there's no predicted time and no scheduled time
    nil
  end

  @spec last_stop?(t) :: boolean
  def last_stop?(%PredictedSchedule{schedule: %Schedule{last_stop?: last_stop?}}) do
    last_stop?
  end

  def last_stop?(%PredictedSchedule{}) do
    false
  end

  @doc """
  Retrieves status from predicted schedule if one is available
  """
  @spec status(PredictedSchedule.t()) :: String.t() | nil
  def status(%PredictedSchedule{prediction: %Prediction{status: status}}), do: status
  def status(_predicted_schedule), do: nil

  @doc """
  Determines if the given predicted schedule occurs after the given time
  """
  @spec upcoming?(PredictedSchedule.t(), DateTime.t()) :: boolean
  def upcoming?(
        %PredictedSchedule{
          schedule: nil,
          prediction: %Prediction{time: nil, departing?: departing?}
        },
        _
      ) do
    departing?
  end

  def upcoming?(ps, %{__struct__: mod} = current_time) do
    # in the tests, schedule.time and prediction.time are NaiveDateTime,
    # rather than DateTime, structs. Luckily they both have a `diff`
    # function, so we can use the `__struct__` attribute to call the
    # correct function.
    mod.compare(time(ps) || current_time, current_time) == :gt
  end

  @doc """
  Determines if this `PredictedSchedule` is departing.
  Departing status is determined by the `pickup_type` field on schedules
  and the `departing?` or `status` field on Predictions. Schedules are preferred for
  determining departing? status.
  """
  @spec departing?(PredictedSchedule.t()) :: boolean
  def departing?(%PredictedSchedule{schedule: nil, prediction: prediction}) do
    prediction.departing?
  end

  def departing?(%PredictedSchedule{schedule: schedule}) do
    schedule.pickup_type != 1
  end

  @doc """
  Returns true if the PredictedSchedule doesn't have a prediction or schedule.
  """
  @spec empty?(PredictedSchedule.t()) :: boolean
  def empty?(%__MODULE__{schedule: nil, prediction: nil}), do: true
  def empty?(%__MODULE__{}), do: false

  @doc """

  Given a Predicted schedule and an order of keys, call the given function
  with the prediction/schedule that's not nil.  If all are nil, then return
  the default value.

  """
  @spec map_optional(
          PredictedSchedule.t(),
          [:schedule | :prediction],
          any,
          (Schedule.t() | Prediction.t() -> any)
        ) :: any
  def map_optional(predicted_schedule, ordering, default \\ nil, func)

  def map_optional(nil, _ordering, default, _func) do
    default
  end

  def map_optional(_predicted_schedule, [], default, _func) do
    default
  end

  def map_optional(predicted_schedule, [:schedule | rest], default, func) do
    case predicted_schedule.schedule do
      nil -> map_optional(predicted_schedule, rest, default, func)
      schedule -> func.(schedule)
    end
  end

  def map_optional(predicted_schedule, [:prediction | rest], default, func) do
    case predicted_schedule.prediction do
      nil -> map_optional(predicted_schedule, rest, default, func)
      prediction -> func.(prediction)
    end
  end

  @spec is_schedule_after?(PredictedSchedule.t(), DateTime.t()) :: boolean
  def is_schedule_after?(%PredictedSchedule{schedule: nil}, _time), do: false

  def is_schedule_after?(%PredictedSchedule{schedule: schedule}, time) do
    DateTime.compare(schedule.time, time) == :gt
  end

  @spec sort_predicted_schedules(PredictedSchedule.t()) ::
          {integer, non_neg_integer, non_neg_integer}
  defp sort_predicted_schedules(%PredictedSchedule{schedule: nil, prediction: prediction}),
    do: {1, prediction.stop_sequence, to_unix(prediction.time)}

  defp sort_predicted_schedules(%PredictedSchedule{schedule: schedule}),
    do: {2, schedule.stop_sequence, to_unix(schedule.time)}

  def sort_with_status(%PredictedSchedule{
        schedule: _schedule,
        prediction: %Prediction{time: nil, status: status}
      })
      when not is_nil(status) do
    {0, status_order(status)}
  end

  def sort_with_status(predicted_schedule),
    do: {1, predicted_schedule |> time |> to_unix()}

  @spec status_order(String.t()) :: non_neg_integer | :sort_max
  defp status_order("Boarding"), do: 0
  defp status_order("Approaching"), do: 1

  defp status_order(status) do
    case Integer.parse(status) do
      {num, _stops_away} -> num + 1
      _ -> :sort_max
    end
  end

  defp to_unix(%DateTime{} = time) do
    DateTime.to_unix(time)
  end

  defp to_unix(%NaiveDateTime{} = time) do
    time
    |> DateTime.from_naive!("Etc/UTC")
    |> to_unix()
  end

  defp to_unix(nil) do
    nil
  end

  @doc """
  Returns the time difference between a schedule and prediction. If either is nil, returns 0.
  """
  @spec delay(PredictedSchedule.t() | nil) :: integer
  def delay(nil), do: 0

  def delay(%PredictedSchedule{schedule: schedule, prediction: prediction})
      when is_nil(schedule) or is_nil(prediction),
      do: 0

  def delay(%PredictedSchedule{schedule: schedule, prediction: prediction}) do
    case prediction.time do
      %{__struct__: mod} = time ->
        # in the tests, schedule.time and prediction.time are NaiveDateTime,
        # rather than DateTime, structs. Luckily they both have a `diff`
        # function, so we can use the `__struct__` attribute to call the
        # correct function.
        seconds = mod.diff(time, schedule.time)
        div(seconds, 60)

      _ ->
        0
    end
  end

  @doc """
  Determines if the delay between a predicted and scheduled time are represented
  as different minutes
  """
  @spec minute_delay?(PredictedSchedule.t() | nil) :: boolean
  def minute_delay?(nil), do: false

  def minute_delay?(%PredictedSchedule{schedule: schedule, prediction: prediction})
      when is_nil(schedule) or is_nil(prediction) do
    false
  end

  def minute_delay?(%PredictedSchedule{schedule: schedule, prediction: prediction} = ps) do
    if prediction.time do
      delay(ps) > 0 or schedule.time.minute != prediction.time.minute
    else
      false
    end
  end

  @doc """
  Replaces the stop for both predicted and schedule.
  """
  @spec put_stop(PredictedSchedule.t(), Stops.Stop.t()) :: PredictedSchedule.t()
  def put_stop(
        %PredictedSchedule{schedule: schedule, prediction: prediction} = predicted_schedule,
        %Stops.Stop{} = stop
      ) do
    new_schedule = if schedule, do: %{schedule | stop: stop}, else: schedule
    new_prediction = if prediction, do: %{prediction | stop: stop}, else: prediction
    %{predicted_schedule | prediction: new_prediction, schedule: new_schedule}
  end
end
