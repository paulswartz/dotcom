defmodule Facilities.ApplicationTest do
  @moduledoc false
  use ExUnit.Case

  describe "start/2" do
    test "can start the application" do
      # should have already been started
      assert {:error, {:already_started, _pid}} = Facilities.Application.start(:permanent, [])
    end
  end
end
