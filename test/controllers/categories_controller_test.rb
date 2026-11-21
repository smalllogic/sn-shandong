require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  test "root cover appears in desktop and mobile navigation while hidden categories stay absent" do
    category = Category.create!(name: "Refrigeration", slug: "refrigeration")
    category.image.attach(io: File.open(Rails.root.join("app/assets/images/categories_banner.jpg")),
                          filename: "navigation-cover.jpg", content_type: "image/jpeg")
    get categories_path
    assert_response :success
    assert_select "[data-category-cover-navigation] a[href=?] img", category_path(category), count: 1
    assert_select "nav a[href=?] img", category_path(category), count: 2

    sku = Sku.create!(name: "Commercial Fridge", category: category, status: "active")
    [products_path, products_path(q: "Fridge"), category_path(category), sku_path(sku)].each do |path|
      get path
      follow_redirect! if response.redirect?
      assert_response :success
      assert_select "[data-category-cover-navigation]", count: 1
      assert_select "nav a[href=?] img", category_path(category), count: 2
      assert_select "[data-category-compact-navigation]", count: 0
    end

    [root_path, factory_path, contact_path, faqs_path, posts_path].each do |path|
      get path
      follow_redirect! if response.redirect?
      assert_response :success
      assert_select "[data-category-compact-navigation]", count: 1
      assert_select "nav a[href=?] img", category_path(category), count: 0
      assert_select "[data-category-cover-navigation]", count: 0
      assert_select "[data-category-compact-navigation] a[href=?] svg", category_path(category), count: 1
    end

    category.update!(hidden: true)
    get categories_path
    assert_select "nav a[href=?]", category_path(category), count: 0
  end

  test "navigation submenus contain only visible direct children and only on product pages" do
    root = Category.create!(name: "Refrigeration", slug: "refrigeration")
    child = Category.create!(name: "Display Cabinets", parent: root)
    grandchild = Category.create!(name: "Deep Category", parent: child)
    hidden_child = Category.create!(name: "Hidden Category", parent: root, hidden: true)
    child.image.attach(io: File.open(Rails.root.join("app/assets/images/categories_banner.jpg")),
                       filename: "child-cover.jpg", content_type: "image/jpeg")
    sku = Sku.create!(name: "Fridge", category: grandchild, status: "active")

    [products_path, products_path(q: "Fridge"), categories_path, sku_path(sku)].each do |path|
      get path
      assert_response :success
      assert_select "nav [data-category-submenu]", count: 2
      assert_select "nav [data-category-submenu] a[href=?] img", category_path(child), count: 2
      assert_select "nav a[href=?]", category_path(grandchild), count: 0
      assert_select "nav a[href=?]", category_path(hidden_child), count: 0
      assert_select "nav [data-category-submenu] [data-category-submenu]", count: 0
    end

    [root_path, factory_path, posts_path, faqs_path, contact_path].each do |path|
      get path
      assert_response :success
      assert_select "nav [data-category-submenu]", count: 0
      assert_select "nav a[href=?]", category_path(child), count: 0
      assert_select "nav button[aria-controls^=mobile-category-submenu]", count: 0
      assert_select "[data-category-compact-navigation] a[href=?] svg", category_path(root), count: 1
    end
  end

  test "should get index" do
    get categories_index_url
    assert_response :success
  end

  test "should display a kitchen equipment channel" do
    Category.create!(name: "Refrigeration", slug: "refrigeration")

    get categories_path(kind: "refrigeration")
    assert_response :success

    get dynamic_channel_path(kind: "refrigeration")
    assert_response :success
  end

  test "should reject an unknown channel" do
    get categories_path(kind: "apple")
    assert_redirected_to categories_path
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
