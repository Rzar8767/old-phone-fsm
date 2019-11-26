defmodule PhoneExerciseTest do
  use ExUnit.Case
  doctest PhoneExercise

  test "greets the world" do
    assert PhoneExercise.hello() == :world
  end
end
