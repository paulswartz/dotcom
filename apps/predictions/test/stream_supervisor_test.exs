defmodule Predictions.StreamSupervisorTest do
  use ExUnit.Case
  alias Predictions.StreamSupervisor

  setup_all do
    old_value = System.get_env("USE_SERVER_SENT_EVENTS")
    System.put_env("USE_SERVER_SENT_EVENTS", "true")

    on_exit(fn ->
      if old_value do
        System.put_env("USE_SERVER_SENT_EVENTS", old_value)
      else
        System.delete_env("USE_SERVER_SENT_EVENTS")
      end
    end)

    :ok
  end

  defp close_active_workers(context) do
    StreamSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.each(&DynamicSupervisor.terminate_child(StreamSupervisor, elem(&1, 1)))

    context
  end

  setup :close_active_workers

  describe "start_link/1" do
    test "StreamSupervisor is started along with registry" do
      assert {:error, {:already_started, _}} = StreamSupervisor.start_link([])

      assert {:error, {:already_started, _}} =
               Registry.start_link(keys: :unique, name: :prediction_streams_registry)
    end
  end

  describe "init/1" do
    test "StreamSupervisor runs DynamicSupervisor.init" do
      {:ok, %{strategy: :one_for_one}} = StreamSupervisor.init([])
    end
  end

  describe "ensure_stream_is_started/1" do
    test "starts a stream if not already started" do
      prediction_key = "route=Purple:stop=awesome-station:direction=1"
      assert {:ok, _pid} = StreamSupervisor.ensure_stream_is_started(prediction_key)
    end

    test "returns existing stream from registry" do
      prediction_key = "route=Pink:stop=place:direction=0"
      {:ok, pid} = StreamSupervisor.ensure_stream_is_started(prediction_key)
      assert {:ok, ^pid} = StreamSupervisor.ensure_stream_is_started(prediction_key)
    end
  end

  describe "stop_stream/1" do
    test "closes a stream by registered key" do
      prediction_key = "stop=there2000"
      {:ok, pid} = StreamSupervisor.ensure_stream_is_started(prediction_key)
      assert Process.alive?(pid)

      assert [{_, ^pid, :supervisor, [Predictions.StreamSupervisor.Worker]}] =
               DynamicSupervisor.which_children(Predictions.StreamSupervisor)

      :ok = StreamSupervisor.stop_stream(prediction_key)
      refute Process.alive?(pid)
      assert [] = DynamicSupervisor.which_children(Predictions.StreamSupervisor)
    end
  end
end
