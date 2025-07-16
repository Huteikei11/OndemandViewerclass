require "test_helper"

class VideoAccessControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get video_access_index_url
    assert_response :success
  end

  test "should get new" do
    get video_access_new_url
    assert_response :success
  end

  test "should get create" do
    get video_access_create_url
    assert_response :success
  end
end
