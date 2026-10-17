require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get categories_index_url
    assert_response :success
  end

  test "should redirect if category not found" do
    get categories_index_url(category_id: 999999)
    assert_redirected_to categories_path
    follow_redirect!
    assert_match "未找到指定的分类", response.body
  end

  test "should get show" do
    @category = Category.create!(name: "Refrigeration", slug: "refrigeration")
    get categories_index_url(category_id: @category.id)
    assert_response :success
  end

  test "should handle common missing routes" do
    get "/apple-touch-icon.png"
    assert_response :not_found

    get "/wp-includes/something"
    assert_response :not_found

    get "/product-page/something"
    assert_response :not_found
  end
end
