require "test_helper"

class SkuTest < ActiveSupport::TestCase
  test "visible excludes drafts archives and hidden branches" do
    root = Category.create!(name: "Refrigeration", slug: "refrigeration")
    leaf = Category.create!(name: "Leaf", parent: root)
    active = Sku.create!(category: leaf, status: "active")
    draft = Sku.create!(category: leaf, status: "draft")
    archived = Sku.create!(category: leaf, status: "archived")

    assert_includes Sku.visible, active
    assert_not_includes Sku.visible, draft
    assert_not_includes Sku.visible, archived
    root.update!(hidden: true)
    assert_not_includes Sku.visible, active
    assert_equal 3, Sku.where(category: leaf).count
  end

  test "catalog order puts smaller positions first then newer products" do
    category = Category.create!(name: "Refrigeration", slug: "refrigeration")
    old = Sku.create!(category: category, position: 1, created_at: 2.days.ago)
    newer = Sku.create!(category: category, position: 1, created_at: 1.day.ago)
    last = Sku.create!(category: category, position: 10)

    assert_equal [newer.id, old.id, last.id], Sku.in_catalog_order.pluck(:id)
  end
  # test "the truth" do
  #   assert true
  # end
end
