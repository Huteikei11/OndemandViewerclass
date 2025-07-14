require "test_helper"

class UserResponsesControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get user_responses_create_url
    assert_response :success
  end
end
