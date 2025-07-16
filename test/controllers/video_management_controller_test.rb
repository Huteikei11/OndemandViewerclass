require "test_helper"

class VideoManagementControllerTest < ActionDispatch::IntegrationTest
  test "should get analytics" do
    get video_management_analytics_url
    assert_response :success
  end

  test "should get add_manager" do
    get video_management_add_manager_url
    assert_response :success
  end
end
