require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test "renders 404 HTML response for unknown HTML path" do
    get "/some_non_existent_page_path"
    assert_response :not_found
    assert_equal "text/html", response.media_type
  end

  test "renders 404 JSON response for unknown JSON path" do
    get "/some_non_existent_path.json", as: :json
    assert_response :not_found
    assert_equal "application/json", response.media_type
  end
end
