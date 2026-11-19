require "test_helper"

class CatalogVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    @root = Category.create!(name: "Refrigeration", slug: "refrigeration")
    @public_leaf = Category.create!(name: "Public leaf", parent: @root)
    @hidden_branch = Category.create!(name: "Hidden branch", parent: @root, hidden: true)
    @hidden_leaf = Category.create!(name: "Hidden leaf", parent: @hidden_branch, featured: true)
    @public_sku = Sku.create!(name: "Public product", category: @public_leaf, status: "active", position: 10)
    @first_sku = Sku.create!(name: "First product", category: @public_leaf, status: "active", position: 1)
    @hidden_sku = Sku.create!(name: "Hidden product", category: @hidden_leaf, status: "active")
    @draft = Sku.create!(name: "Draft product", category: @public_leaf, status: "draft")
  end

  test "lists search and related products obey public visibility" do
    [categories_path, categories_path(kind: @root.slug),
     categories_path(category_id: @root.slug), products_path,
     products_path(q: "product"), sku_path(@public_sku)].each do |path|
      get path
      assert_response :success
      assert_select "a[href=?]", sku_path(@hidden_sku), count: 0
      assert_select "a[href=?]", sku_path(@draft), count: 0
      assert_select "a[href=?]", sku_path(@first_sku), minimum: 1
    end
  end

  test "category lists put lower positions first" do
    get categories_path(category_id: @public_leaf.slug)
    links = css_select("a[href^='/skus/']").map { |node| node['href'] }
    assert_operator links.index(sku_path(@first_sku)), :<, links.index(sku_path(@public_sku))
  end

  test "a hidden ancestor prevents direct category access and homepage recommendations" do
    get category_path(@hidden_leaf)
    assert_redirected_to categories_path
    get categories_path(category_id: @hidden_leaf.slug)
    assert_redirected_to categories_path
    get root_path
    assert_response :success
    assert_no_match @hidden_leaf.name, response.body
  end

  test "moving a visible subtree changes channel results" do
    target = Category.create!(name: "Cooking", slug: "cooking-equipment")
    @public_leaf.update!(parent: target)

    get categories_path(kind: @root.slug)
    assert_select "a[href=?]", sku_path(@public_sku), count: 0
    get categories_path(kind: target.slug)
    assert_select "a[href=?]", sku_path(@public_sku), minimum: 1
  end

  test "cart removes a product that becomes hidden and cannot add it again" do
    post "/order/add_item", params: { sku_id: @public_sku.id }
    assert_response :success
    @root.update!(hidden: true)
    get "/order/cart_items"
    assert_response :success
    assert_equal [], response.parsed_body.fetch("items")
    assert_equal 0, response.parsed_body.fetch("count")
    post "/order/add_item", params: { sku_id: @public_sku.id }
    assert_response :not_found
  end
end
