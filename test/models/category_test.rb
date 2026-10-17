require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "should be valid with valid slug" do
    category = Category.new(name: "Refrigeration", slug: "refrigeration")
    assert category.valid?
  end

  test "should be invalid with invalid slug format" do
    parent = Category.create!(name: "Refrigeration", slug: "refrigeration")
    category = Category.new(name: "Test", parent: parent, slug: "Test Category")
    assert_not category.valid?
    assert_includes category.errors[:slug], "只能包含小写字母、数字和连字符"
  end

  test "to_param should return slug" do
    category = Category.new(name: "Refrigeration", slug: "refrigeration")
    assert_equal "refrigeration", category.to_param
  end

  test "should require slug" do
    category = Category.new(name: "Invalid Root Slug")
    assert_not category.valid?
  end

  test "uses an admin translated name as the required fallback name" do
    parent = Category.create!(name: "Refrigeration", slug: "refrigeration")
    child = Category.new(name_en: "Counter Refrigerator", parent: parent)

    assert child.valid?
    assert_equal "Counter Refrigerator", child.name
    assert_equal "counter-refrigerator", child.slug
  end
end
