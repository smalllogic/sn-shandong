require "test_helper"
require "base64"

class SkuConfigurationsTest < ActionDispatch::IntegrationTest
  setup do
    category = Category.create!(name: "Refrigeration", slug: "refrigeration")
    @sku = Sku.create!(name: "Display cabinet", sku_code: "CAB-01", category: category, status: "active")
    @other_sku = Sku.create!(name: "Other cabinet", category: category, status: "active")
  end

  test "an administrator creates a group and uploads a SKU-specific option image" do
    sign_in User.create!(email: "configuration-admin@example.com", password: "password123", role: "super_admin")
    get edit_admin_sku_path(@sku)
    assert_response :success
    assert_select "a[href=?]", admin_sku_sku_configuration_groups_path(@sku)
    get new_admin_sku_sku_configuration_group_path(@sku)
    assert_response :success
    assert_select "template input[name*='NEW_OPTION']"

    png = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jKeYAAAAASUVORK5CYII=")
    image = Rack::Test::UploadedFile.new(StringIO.new(png), "image/png", original_filename: "black.png")
    post admin_sku_sku_configuration_groups_path(@sku), params: {
      sku_configuration_group: {
        name_en: "Marble countertop", name_zh: "大理石台面", currency: "usd",
        options_attributes: {
          "0" => { name_en: "White", name_zh: "白色", surcharge: "0", position: "0" },
          "1" => { name_en: "Black", name_zh: "黑色", model_code: "MAR-BLK", surcharge: "80", position: "1", image: image }
        }
      }
    }
    assert_redirected_to admin_sku_sku_configuration_groups_path(@sku)
    group = @sku.configuration_groups.sole
    black = group.options.find_by!(model_code: "MAR-BLK")
    assert black.image.attached?

    get sku_path(@sku, locale: "zh-CN")
    assert_response :success
    assert_select "legend", text: "大理石台面"
    assert_select "input[type=radio][name=?][checked]", "configuration_group_#{group.id}", count: 1
    assert_select "input[type=radio][value=?][data-surcharge-cents='8000']", black.id.to_s
    assert_select "img[src*='black.png']"
    get sku_path(@other_sku)
    assert_select "#sku-configuration-heading", count: 0

    get edit_admin_sku_sku_configuration_group_path(@other_sku, group)
    assert_response :not_found
  end

  test "configuration choice stays with each inquiry line and saved orders keep the quoted details" do
    countertop = add_group(@sku, "Marble", "Black", 80)
    gray = countertop.sku_configuration_group.options.create!(name_en: "Gray", surcharge: 50, position: 1)
    back = add_group(@sku, "Back panel", "Walnut", 40)
    wrong_sku = add_group(@other_sku, "Different model", "Oak", 20)

    post add_item_order_path, params: { sku_id: @sku.id }, as: :json
    assert_response :unprocessable_entity
    assert_equal sku_path(@sku, anchor: "sku-configuration-heading"), response.parsed_body["configuration_url"]
    [[countertop.id], [countertop.id, gray.id], [wrong_sku.id, back.id]].each do |invalid|
      post add_item_order_path, params: { sku_id: @sku.id, option_ids: invalid }, as: :json
      assert_response :unprocessable_entity
    end
    [[countertop.id, back.id], [back.id, countertop.id], [gray.id, back.id]].each do |ids|
      post add_item_order_path, params: { sku_id: @sku.id, option_ids: ids }, as: :json
      assert_response :success
    end

    get cart_items_order_path
    items = response.parsed_body.fetch("items")
    assert_equal [2, 1], items.pluck("quantity")
    assert_equal [["Black", "Walnut"], ["Gray", "Walnut"]], items.map { |item| item.fetch("configuration").pluck("option") }
    patch update_item_order_path, params: { line_key: items.last["line_key"], quantity: 3 }, as: :json
    assert_response :success

    post order_path, params: { name: "Customer", country: "USA", phone: "5551234", email: "customer@example.com" }, as: :json
    assert_response :success
    order = Order.last
    assert_equal [2, 3], order.order_items.order(:id).pluck(:quantity)
    saved = order.order_items.order(:id).first
    assert_equal ["80.0", "40.0"], saved.configuration_snapshot.pluck("surcharge")
    countertop.update!(name_en: "Updated finish", surcharge: 99)
    assert_equal "Black", saved.reload.configuration_snapshot.first.fetch("option")
  end

  test "disabled options are excluded and stale selections cannot be submitted" do
    option = add_group(@sku, "Finish", "Black", 80)
    option.sku_configuration_group.options.create!(name_en: "White", surcharge: 0)
    post add_item_order_path, params: { sku_id: @sku.id, option_ids: [option.id] }, as: :json
    assert_response :success
    option.update!(enabled: false)
    get sku_path(@sku)
    assert_select "input[type=radio][value=?]", option.id.to_s, count: 0

    assert_no_difference "Order.count" do
      post order_path, params: { name: "Customer", country: "USA", phone: "5551234", email: "customer@example.com" }, as: :json
      assert_response :unprocessable_entity
    end
  end

  private

  def add_group(sku, group_name, option_name, price)
    group = sku.configuration_groups.create!(name_en: group_name, currency: "USD",
      options_attributes: [{ name_en: option_name, surcharge: price }])
    group.options.first
  end
end
