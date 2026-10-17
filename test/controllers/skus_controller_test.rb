require "test_helper"

class SkusControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    category = Category.create!(name: "Refrigeration", slug: "refrigeration")
    @sku = Sku.create!(name: "Commercial Fridge", sku_code: "SKU-TEST-1", category: category, price: 100, status: "active")
    get sku_url(id: @sku.id)
    assert_response :success
  end
end
