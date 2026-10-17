require "test_helper"

class DealerFlowTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      email: "admin_test@sinower.com",
      password: "password123",
      password_confirmation: "password123",
      role: "super_admin",
      admin: true
    )
  end

  test "guest user sees login and register links on home page" do
    get root_url
    assert_response :success
    assert_select "a[href=?]", new_user_session_path
    assert_select "a[href=?]", new_user_registration_path
  end

  test "user can register and apply as dealer" do
    post user_registration_url, params: {
      user: {
        email: "dealer_applicant@example.com",
        password: "password123",
        password_confirmation: "password123",
        apply_dealer: "1",
        company_name: "Grand Kitchen Equipment",
        contact_name: "John Doe",
        phone: "+86 13800138000",
        country: "France",
        dealer_notes: "We distribute cooking equipment in Paris."
      }
    }

    assert_redirected_to dealer_root_url
    follow_redirect!
    assert_response :success

    applicant = User.find_by(email: "dealer_applicant@example.com")
    assert_not_nil applicant
    assert_equal "pending", applicant.dealer_status
    assert_equal "Grand Kitchen Equipment", applicant.company_name
    assert_equal "France", applicant.country
    assert applicant.dealer_pending?
  end

  test "admin can approve and reject dealer applications" do
    applicant = User.create!(
      email: "dealer_to_approve@example.com",
      password: "password123",
      password_confirmation: "password123",
      dealer_status: "pending",
      company_name: "Berlin Foodservice GmbH",
      contact_name: "Hans Muller"
    )

    sign_in @admin

    get admin_dealers_url
    assert_response :success
    assert_includes response.body, "Berlin Foodservice GmbH"

    # Approve dealer
    patch approve_admin_dealer_url(applicant)
    assert_redirected_to admin_dealers_url

    applicant.reload
    assert_equal "approved", applicant.dealer_status
    assert_equal "dealer", applicant.role
    assert applicant.dealer_approved?
    assert applicant.dealer?
    assert_not_nil applicant.dealer_approved_at

    # Reject dealer
    patch reject_admin_dealer_url(applicant)
    assert_redirected_to admin_dealers_url

    applicant.reload
    assert_equal "rejected", applicant.dealer_status
    assert applicant.dealer_rejected?
  end

  test "dealer can view submitted inquiries and orders in dealer backend" do
    dealer = User.create!(
      email: "approved_dealer@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "dealer",
      dealer_status: "approved",
      company_name: "Milano Restaurant Supplies",
      contact_name: "Marco Rossi"
    )

    inquiry = ContactMessage.create!(
      user: dealer,
      name: "Marco Rossi",
      email: "approved_dealer@example.com",
      message: "Inquiry about 40 units stainless steel work tables."
    )

    order = Order.create!(
      user: dealer,
      name: "Marco Rossi",
      email: "approved_dealer@example.com",
      phone: "+39 333 123456",
      country: "Italy",
      status: "pending",
      message: "Urgent order for upcoming project."
    )

    category = Category.create!(name: "Refrigeration", slug: "refrigeration")
    sku = Sku.create!(name: "Commercial Freezer", sku_code: "FRZ-100", category: category, price: 500, status: "active")
    order.order_items.create!(sku: sku, quantity: 2)

    sign_in dealer

    # Dealer dashboard
    get dealer_root_url
    assert_response :success
    assert_includes response.body, "Inquiry about 40 units"
    assert_includes response.body, "订单 ##{order.id}"

    # Dealer inquiries index & show
    get dealer_inquiries_url
    assert_response :success
    assert_includes response.body, "Inquiry about 40 units"

    get dealer_inquiry_url(inquiry)
    assert_response :success
    assert_includes response.body, "Inquiry about 40 units stainless steel work tables."

    # Dealer orders index & show
    get dealer_orders_url
    assert_response :success
    assert_includes response.body, "##{order.id}"

    get dealer_order_url(order)
    assert_response :success
    assert_includes response.body, "Commercial Freezer"
    assert_includes response.body, "FRZ-100"
    assert_includes response.body, "2 台/套"
  end

  test "submitting order associates with signed in user" do
    dealer = User.create!(
      email: "order_dealer@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "dealer",
      dealer_status: "approved"
    )

    category = Category.create!(name: "Cooking Equipment", slug: "cooking-equipment")
    sku = Sku.create!(name: "Gas Range", sku_code: "GAS-01", category: category, price: 300, status: "active")

    sign_in dealer

    # Add item to session cart
    post add_item_order_url, params: { sku_id: sku.id }
    assert_response :success

    # Submit order
    post order_url, params: {
      name: "Order Dealer",
      country: "USA",
      phone: "+1 555 1234",
      email: "order_dealer@example.com",
      message: "Please ship via sea freight."
    }
    assert_response :success

    order = Order.last
    assert_equal dealer.id, order.user_id
    assert_equal 1, order.order_items.count
    assert_equal sku.id, order.order_items.first.sku_id
  end
end
