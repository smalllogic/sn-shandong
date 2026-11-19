require "test_helper"

class CatalogFiltersTest < ActionDispatch::IntegrationTest
  setup do
    @root = Category.create!(name: "Refrigeration", slug: "refrigeration")
    @leaf = Category.create!(name: "Fridges", parent: @root)
    @hidden_leaf = Category.create!(name: "Hidden", parent: @root, hidden: true)
    @capacity = field("capacity", "Capacity", "number", "Capacity\nVolume", "L")
    @door = field("door", "Door type", "choice", "Door type")
    @temperature = field("temperature", "Working temperature", "interval", "Temperature\nTemperatureRange", "°C")
    @price = field("budget", "Price", "price", nil, "USD")
    [@capacity, @door, @temperature, @price].each_with_index do |filter_field, position|
      @root.category_filters.create!(catalog_filter_field: filter_field, position: position)
    end
  end

  test "a large collection combines inclusive ranges and OR choices before pagination" do
    22.times { |index| product("Nonmatch #{index}", "100 L", "Glass", "-18 to -10", position: index) }
    first = product("Match fridge", "500 L", "Glass", "-18 °C - -10 °C", position: 100, price: 200)
    second = product("Match cooler", "600 L", "Solid", "−18～−10℃", position: 101, price: 250, capacity_name: "Volume")
    unit_mismatch = product("Wrong unit", "500 kg", "Glass", "-18 - -10", price: 220)
    hidden = product("Hidden", "500 L", "Glass", "-18 - -10", category: @hidden_leaf, price: 220)
    unpriced = product("No price", "500 L", "Glass", "-18 - -10")
    wrong_interval = product("Different temperature", "500 L", "Glass", "-9 - 5", price: 250)
    third_door = product("Different door", "500 L", "Wood", "-18 - -10", price: 240)

    get dynamic_channel_path(kind: @root.slug), params: {
      filters: { capacity: { min: "500", max: "600" }, door: %w[glass solid], temperature: "-10", budget: { max: "250" } }
    }
    assert_response :success
    assert_select "[role=status]", text: "2 products"
    [first, second].each { |sku| assert_select "a[href=?]", sku_path(sku), minimum: 1 }
    [unit_mismatch, hidden, unpriced, wrong_interval, third_door].each { |sku| assert_select "a[href=?]", sku_path(sku), count: 0 }

    # Removing a chip preserves numeric conditions as decimal URL text.
    remove_price = css_select('a[aria-label="Remove filter Price"]').first
    get remove_price["href"]
    assert_response :success
    assert_select "[role=status]", text: "3 products"
    assert_select "a[href=?]", sku_path(unpriced), minimum: 1
  end

  test "unconfigured and disabled filters cannot constrain another collection" do
    sku = product("Basic", "500 L", "Glass", "-18 - -10")
    @leaf.category_filters.create!(catalog_filter_field: @price, enabled: false)
    get categories_path(category_id: @leaf.slug), params: { filters: { capacity: { min: "9999" }, budget: { min: "9999" } } }
    assert_response :success
    assert_select "input[name^='filters']", count: 0
    assert_select "a[href=?]", sku_path(sku), minimum: 1
  end

  test "a required interval must be fully covered rather than merely overlap" do
    coverage = field("temperature_coverage", "Temperature coverage", "interval_cover", "Temperature", "°C")
    @root.category_filters.create!(catalog_filter_field: coverage)
    covers = product("Covers both", "500 L", "Glass", "-18 to -10")
    overlaps = product("Only overlaps", "500 L", "Glass", "-18 to -15")

    get categories_path(category_id: @root.slug, filters: { temperature_coverage: { min: "-16", max: "-12" } })
    assert_response :success
    assert_select "a[href=?]", sku_path(covers), minimum: 1
    assert_select "a[href=?]", sku_path(overlaps), count: 0
  end

  test "invalid bounds show an error and zero results retain the selected condition" do
    product("Basic", "500 L", "Glass", "-18 - -10")
    get categories_path(category_id: @root.slug, filters: { capacity: { min: "800", max: "200" } })
    assert_response :success
    assert_select "[role=alert]", text: /Check the values for Capacity/

    get categories_path(category_id: @root.slug, filters: { door: ["unavailable"] }, locale: "zh-CN")
    assert_response :success
    assert_select "[role=status]", text: "0 件商品"
    assert_select "input[type=checkbox][checked][value=unavailable]"
    assert_select "a", text: "清空条件"
  end

  test "an administrator can publish a field and see its data coverage" do
    product("Cabinet", "500 L", "Glass", "-18 - -10")
    sign_in User.create!(email: "filter-admin@example.com", password: "password123", role: "super_admin")
    get new_admin_catalog_filter_field_path
    assert_response :success
    assert_select "td", text: "Capacity"
    post admin_catalog_filter_fields_path, params: {
      catalog_filter_field: { code: "cabinet_capacity", label_en: "Cabinet capacity", kind: "number", unit: "L", legacy_names: "Capacity" }
    }
    assert_redirected_to admin_catalog_filter_fields_path
    new_field = CatalogFilterField.find_by!(code: "cabinet_capacity")
    get new_admin_category_category_filter_path(@leaf)
    assert_response :success
    post admin_category_category_filters_path(@leaf), params: { category_filter: { catalog_filter_field_id: new_field.id, enabled: "1", position: 3 } }
    assert_redirected_to admin_category_category_filters_path(@leaf)
    follow_redirect!
    assert_select "td", text: "1 / 1 件上架商品"

    get categories_path(category_id: @leaf.slug)
    assert_response :success
    assert_select "legend", text: "Cabinet capacity (L)"
    assert_select "legend", text: "Door type", count: 0
  end

  test "visitors cannot change filter configuration" do
    post admin_catalog_filter_fields_path, params: { catalog_filter_field: { code: "unapproved" } }
    assert_redirected_to new_user_session_path
    assert_not CatalogFilterField.exists?(code: "unapproved")
  end

  private

  def field(code, label, kind, aliases, unit = nil)
    CatalogFilterField.create!(code: code, label_en: label, kind: kind, legacy_names: aliases, unit: unit)
  end

  def product(name, capacity, door, temperature, category: @leaf, price: nil, position: 0, capacity_name: "Capacity")
    Sku.create!(name: name, category: category, price: price, position: position, status: "active", specifications: [
      {key: capacity_name, value: capacity}, {key: "Door type", value: door}, {key: "Temperature", value: temperature}
    ])
  end
end
