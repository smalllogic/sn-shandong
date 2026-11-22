require "test_helper"
require "minitest/mock"

class BusinessRulesTest < ActionDispatch::IntegrationTest
  setup do
    @root = Category.create!(name: "Refrigeration", slug: "refrigeration")
    @sku = Sku.create!(name: "Display Cabinet", category: @root, status: "active")
    @operator = users(:one)
  end

  test "guest inquiries stay unassigned and retrying saves only one historical record" do
    add_to_inquiry(@sku)
    details = { name: "Guest", country: "FR", phone: "555 0100", email: users(:two).email, message: "Deliver to our rear entrance" }
    assert_difference "Order.count", 1 do
      2.times do
        post order_path, params: details, as: :json
        assert_response :success
      end
    end

    order = Order.find_by!(message: details[:message])
    assert_nil order.user_id
    line = order.order_items.sole
    code = @sku.sku_code
    @sku.update!(name: "Renamed Cabinet", sku_code: "CAB-NEW")
    assert_equal "Display Cabinet", line.reload.product_name
    assert_equal code, line.product_code

    sign_in @operator
    get admin_order_path(order)
    assert_response :success
    assert_includes response.body, details[:message]
    assert_includes response.body, "Display Cabinet"
    delete admin_sku_path(@sku)
    assert_redirected_to admin_skus_path
    assert Sku.exists?(@sku.id)
  end

  test "an unavailable inquiry item must be resolved before a partial order can be submitted" do
    other = Sku.create!(name: "Freezer", category: @root, status: "active")
    add_to_inquiry(@sku)
    add_to_inquiry(other)
    @sku.update!(status: "archived")

    get cart_items_order_path
    assert_equal 2, response.parsed_body.fetch("items").size
    assert_equal 1, response.parsed_body.fetch("items").count { |item| item["unavailable"] }
    details = { name: "Guest", country: "FR", phone: "555 0100", email: "audit@example.test" }
    assert_no_difference "Order.count" do
      post order_path, params: details, as: :json
      assert_response :unprocessable_entity
    end

    delete remove_item_order_path, params: { line_key: @sku.id.to_s }, as: :json
    patch update_item_order_path, params: { line_key: other.id.to_s, quantity: OrderItem::MAX_QUANTITY + 1 }, as: :json
    assert_response :unprocessable_entity
    assert_difference "Order.count", 1 do
      post order_path, params: details, as: :json
      assert_response :success
    end
    assert_equal [other.id], Order.last.order_items.pluck(:sku_id)
  end

  test "content editors cannot handle orders and ordinary admins cannot delete them" do
    order = Order.create!(name: "Guest", country: "FR", phone: "555 0100", email: "guest@example.test", status: "pending")
    editor = users(:two)
    editor.update!(role: "editor")
    sign_in editor
    get admin_order_path(order)
    assert_redirected_to admin_root_path
    patch admin_order_path(order), params: { order: { status: "replied" } }
    assert_redirected_to admin_root_path
    assert order.reload.pending?

    editor.update!(role: "admin")
    get admin_order_path(order)
    assert_response :success
    delete admin_order_path(order)
    assert_redirected_to admin_root_path
    assert Order.exists?(order.id)
  end

  test "contact form preserves a failed submission and guest email never assigns ownership" do
    fields = { name: "Guest", email: users(:two).email, message: "Delivery and installation question" }
    post contact_path, params: { contact_message: fields }
    assert_response :unprocessable_entity
    assert_select "textarea", text: fields[:message]

    verification_response = Net::HTTPOK.new("1.1", "200", "OK")
    verification_response.define_singleton_method(:body) { '{"success":true}' }
    Net::HTTP.stub(:start, ->(*, **) { verification_response }) do
      assert_difference "ContactMessage.count", 1 do
        post contact_path, params: {
          contact_message: fields, privacy_agreement: "1", "cf-turnstile-response": "test-verification"
        }
        assert_redirected_to contact_path
      end
    end
    assert_nil ContactMessage.find_by!(message: fields[:message]).user_id
  end

  test "price filters display the shared catalog currency instead of their individual units" do
    @sku.update!(price: 200)
    SiteConfig.get.update!(catalog_currency: "EUR")
    price_field = CatalogFilterField.create!(code: "price", kind: "price", label_en: "Price", unit: "USD")
    @root.category_filters.create!(catalog_filter_field: price_field)

    get categories_path(category_id: @root.slug, filters: { price: { max: "300" } })
    assert_response :success
    assert_select "form legend", text: "Price (EUR)"
    assert_select "main a[href=?]", sku_path(@sku), minimum: 1
  end

  test "last super administrator cannot be demoted or deleted" do
    sign_in @operator
    patch admin_user_path(@operator), params: { user: { role: "admin" } }
    assert_response :unprocessable_entity
    assert @operator.reload.super_admin?
    delete admin_user_path(@operator)
    assert_redirected_to admin_users_path
    assert User.exists?(@operator.id)
  end

  test "legacy specs render and an explicit empty submission clears all specs" do
    @sku.update!(specifications: { "Capacity" => "500 L" })
    get sku_path(@sku)
    assert_response :success
    assert_includes response.body, "500 L"

    sign_in @operator
    patch admin_sku_path(@sku), params: { sku: { name: "Cabinet" } }
    assert_redirected_to admin_skus_path
    assert_equal({ "Capacity" => "500 L" }, @sku.reload.specifications)

    patch admin_sku_path(@sku), params: { sku: { edit_specifications: "1" } }
    assert_redirected_to admin_skus_path
    assert_empty @sku.reload.specifications
  end

  test "invalid image prevents edits while a valid image saves with the SKU" do
    sign_in @operator
    invalid_file = Rack::Test::UploadedFile.new(StringIO.new("plain text"), "text/plain", original_filename: "invalid.txt")
    patch admin_sku_path(@sku), params: { sku: { name: "Wrong name", images: [invalid_file] } }
    assert_response :unprocessable_entity
    assert_equal "Display Cabinet", @sku.reload.name
    assert_not @sku.images.attached?

    file = Rack::Test::UploadedFile.new(Rails.root.join("app/assets/images/categories_banner.jpg"), "image/jpeg")
    patch admin_sku_path(@sku), params: { sku: { name: "Updated cabinet", images: [file] } }
    assert_redirected_to admin_skus_path
    assert_equal "Updated cabinet", @sku.reload.name
    assert @sku.images.first.blob.service.exist?(@sku.images.first.key)
  end

  test "product index lists root SKUs and deep SKUs without more levels in the dropdown" do
    other_root = Category.create!(name: "Ventilation", slug: "ventilation")
    leaf = 4.times.reduce(other_root) { |parent, level| Category.create!(name: "Level #{level}", parent: parent) }
    deep_sku = Sku.create!(name: "Deep SKU", category: leaf, status: "active")
    assert_not @root.update(parent: other_root)
    assert_nil @root.reload.parent_id
    get products_path
    assert_response :success
    [@sku, deep_sku].each { |sku| assert_select "main a[href=?]", sku_path(sku), count: 1 }
    assert_select "nav [data-category-submenu] a[href=?]", category_path(leaf), count: 0
  end

  private

  def add_to_inquiry(sku)
    post add_item_order_path, params: { sku_id: sku.id }, as: :json
    assert_response :success
  end
end
