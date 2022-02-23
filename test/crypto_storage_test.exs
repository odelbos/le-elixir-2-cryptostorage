defmodule CryptoStorageTest do
  use ExUnit.Case
  doctest CryptoStorage

  test "greets the world" do
    assert CryptoStorage.hello() == :world
  end
end
