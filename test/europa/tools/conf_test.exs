defmodule Europa.Tools.ConfTest do
  use ExUnit.Case, async: true

  alias Europa.Tools.Conf

  setup do
    :ok = Application.put_env(:europa, :conf_test, a: [b: [c: 1]])
  end

  describe "fetch_config!/1" do
    test "returns config value" do
      assert Conf.fetch_config!([:conf_test, :a, :b, :c]) == 1
      assert Conf.fetch_config!(:conf_test) == [a: [b: [c: 1]]]
    end
  end

  describe "get_config/2" do
    test "returns config value" do
      assert Conf.get_config(:conf_test) == [a: [b: [c: 1]]]
    end

    test "returns default value if config not defined" do
      assert Conf.get_config(:fake, a: 123) == [a: 123]
    end
  end
end
