defmodule Vehicles.StreamTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  @stops %JsonApi{
    data: [
      %JsonApi.Item{
        type: "stop",
        id: "stop",
        relationships: %{
          "parent_station" => [
            %JsonApi.Item{
              type: "stop",
              id: "place-stop"
            }
          ]
        }
      }
    ]
  }
  @trips %JsonApi{
    data: [
      %JsonApi.Item{
        type: "trip",
        id: "trip",
        relationships: %{
          "shape" => [
            %JsonApi.Item{
              type: "shape",
              id: "trip-shape"
            }
          ]
        }
      }
    ]
  }
  @vehicles %JsonApi{
    data: [
      %JsonApi.Item{
        type: "vehicle",
        id: "vehicle1",
        attributes: %{
          "current_status" => "STOPPED_AT",
          "direction_id" => 0
        },
        relationships: %{
          "route" => [%JsonApi.Item{id: "route"}],
          "trip" => [%JsonApi.Item{id: "trip"}],
          "stop" => [%JsonApi.Item{id: "stop"}]
        }
      }
    ]
  }

  setup tags do
    {:ok, mock_api} =
      GenStage.from_enumerable([
        %V3Api.Stream.Event{event: :add, data: @stops},
        %V3Api.Stream.Event{event: :add, data: @trips},
        %V3Api.Stream.Event{event: :add, data: @vehicles}
      ])

    name = :"stream_test_#{tags.line}"

    {:ok, mock_api: mock_api, name: name}
  end

  describe "start_link/1" do
    test "starts a GenServer that publishes vehicles", %{mock_api: mock_api, name: name} do
      test_pid = self()

      broadcast_fn = fn Vehicles.PubSub, "vehicles", {type, data} ->
        send(test_pid, {type, data})
        :ok
      end

      assert {:ok, _} =
               Vehicles.Stream.start_link(
                 name: name,
                 broadcast_fn: broadcast_fn,
                 subscribe_to: mock_api
               )

      assert_receive {:add,
                      [
                        %Vehicles.Vehicle{
                          id: "vehicle1",
                          stop_id: "place-stop",
                          shape_id: "trip-shape"
                        }
                      ]}
    end

    test "publishes :remove events as a list of IDs", %{name: name} do
      {:ok, mock_api} =
        GenStage.from_enumerable([
          %V3Api.Stream.Event{event: :remove, data: @vehicles}
        ])

      test_pid = self()

      broadcast_fn = fn Vehicles.PubSub, "vehicles", {type, data} ->
        send(test_pid, {:received_broadcast, {type, data}})
        :ok
      end

      assert {:ok, _} =
               Vehicles.Stream.start_link(
                 name: name,
                 broadcast_fn: broadcast_fn,
                 subscribe_to: mock_api
               )

      assert_receive {:received_broadcast, {type, data}}
      assert type == :remove
      assert data == ["vehicle1"]
    end

    test "logs an error when broadcast fails", %{mock_api: mock_api, name: name} do
      test_pid = self()

      broadcast_fn = fn Vehicles.PubSub, "vehicles", {_type, _data} ->
        send(test_pid, :received_broadcast)
        {:error, "error"}
      end

      log =
        capture_log(fn ->
          {:ok, _} =
            Vehicles.Stream.start_link(
              name: name,
              broadcast_fn: broadcast_fn,
              subscribe_to: mock_api
            )

          :timer.sleep(100)
        end)

      assert_receive :received_broadcast
      assert log =~ "error=#{inspect("error")}"
    end
  end
end
