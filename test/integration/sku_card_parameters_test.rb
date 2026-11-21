require "test_helper"
require "csv"

class SkuCardParametersTest < ActionDispatch::IntegrationTest
  setup do
    category = Category.create!(name: "Refrigeration", slug: "refrigeration")
    @sku = Sku.create!(name: "Display cabinet", sku_code: "CAB-01", category: category, status: "active")
    sign_in User.create!(email: "card-admin@example.com", password: "password123", role: "super_admin")
  end

  test "admin editing shows localized card parameters and clearing hides the block" do
    get edit_admin_sku_path(@sku)
    assert_select "textarea[name='sku[card_parameters_zh]']"
    patch admin_sku_path(@sku), params: { sku: {
      card_parameters_en: "Capacity: 500 L\nVoltage: 220 V",
      card_parameters_zh: " 容量：500 L \r\n\r\n电压：220 V"
    } }
    assert_redirected_to admin_skus_path
    get categories_path(kind: "refrigeration", locale: "zh-CN")
    assert_select "[data-card-parameters] li", count: 2
    assert_select "[data-card-parameters] li", text: "容量：500 L"
    get products_path(q: "Display", locale: "fr")
    assert_select "[data-card-parameters] li", text: "Capacity: 500 L"

    patch admin_sku_path(@sku), params: { sku: { card_parameters_en: "", card_parameters_zh: "" } }
    get categories_path
    assert_select "[data-card-parameters]", count: 0
  end

  test "uploaded CSV updates only supplied languages and rolls back on an invalid SKU" do
    @sku.update!(card_parameters_en: "Old")
    upload([["CAB-01", "容量：500 L\n电压：220 V"]])
    assert_response :see_other
    assert_equal "Old", @sku.reload.card_parameters_en
    assert_equal "容量：500 L\n电压：220 V", @sku.card_parameters_zh

    upload([["CAB-01", "容量：900 L"], ["UNKNOWN", "容量：999 L"]])
    assert_response :see_other
    assert_match "没有唯一匹配", flash[:alert]
    assert_equal "容量：500 L\n电压：220 V", @sku.reload.card_parameters_zh
  end

  private

  def upload(rows)
    content = CSV.generate do |csv|
      csv << %w[sku_code card_parameters_zh]
      rows.each { |row| csv << row }
    end
    file = Rack::Test::UploadedFile.new(StringIO.new(content), "text/csv", original_filename: "card-parameters.csv")
    post import_card_parameters_admin_skus_path, params: { file: file }
  end
end
