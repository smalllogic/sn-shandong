require "test_helper"

class SkusControllerTest < ActionDispatch::IntegrationTest
  test "unpublished products and hidden ancestor products cannot be opened" do
    root = Category.create!(name: "Refrigeration", slug: "refrigeration")
    leaf = Category.create!(name: "Leaf", parent: root)
    sku = Sku.create!(name: "Private product", category: leaf, status: "draft")
    get sku_path(sku)
    assert_redirected_to products_path
    sku.update!(status: "archived")
    get sku_path(sku)
    assert_redirected_to products_path
    sku.update!(status: "active")
    root.update!(hidden: true)
    get sku_path(sku)
    assert_redirected_to products_path
  end
  test "should get show" do
    category = Category.create!(name: "Refrigeration", slug: "refrigeration")
    @sku = Sku.create!(name: "Commercial Fridge", sku_code: "SKU-TEST-1", category: category, price: 100, status: "active")
    get sku_url(id: @sku.id)
    assert_response :success
  end
end
