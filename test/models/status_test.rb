require "test_helper"

class StatusTest < ActiveSupport::TestCase
  test "finished? returns true for Finished status" do
    assert statuses(:finished).finished?
  end

  test "finished? returns false for non-Finished status" do
    refute statuses(:retired).finished?
  end

  test "disqualified? returns true for Disqualified status" do
    assert statuses(:disqualified).disqualified?
  end

  test "disqualified? returns false for other statuses" do
    refute statuses(:finished).disqualified?
  end

  test "technical? returns true for Engine" do
    assert statuses(:engine).technical?
  end

  test "technical? returns false for Finished" do
    refute statuses(:finished).technical?
  end

  test "lapped? returns true for +1 Lap" do
    assert statuses(:lapped_one).lapped?
  end

  test "lapped? returns false for Finished" do
    refute statuses(:finished).lapped?
  end

  test "accident? returns true for Accident" do
    assert statuses(:accident).accident?
  end

  test "accident? returns true for Collision" do
    assert statuses(:collision).accident?
  end

  test "accident? returns false for Finished" do
    refute statuses(:finished).accident?
  end

  test "retired? returns true for Retired" do
    assert statuses(:retired).retired?
  end

  test "retired? returns false for Finished" do
    refute statuses(:finished).retired?
  end

  test "health? returns true for Injured" do
    assert statuses(:injured).health?
  end

  test "health? returns false for Finished" do
    refute statuses(:finished).health?
  end

  test "did_not_start? returns true for Did not qualify" do
    assert statuses(:did_not_qualify).did_not_start?
  end

  test "did_not_start? returns false for Finished" do
    refute statuses(:finished).did_not_start?
  end
end
