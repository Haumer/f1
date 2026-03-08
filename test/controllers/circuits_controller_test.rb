require "test_helper"

class CircuitsControllerTest < ActionDispatch::IntegrationTest
  test "index returns 200" do
    get circuits_path
    assert_response :success
  end

  test "show returns 200" do
    get circuit_path(circuits(:bahrain))
    assert_response :success
  end
end
