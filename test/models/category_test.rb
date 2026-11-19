require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "visibility includes ancestors and recovers when an ancestor is shown" do
    root = Category.create!(name: "Refrigeration", slug: "refrigeration")
    branch = Category.create!(name: "Branch", parent: root, hidden: true)
    leaf = Category.create!(name: "Leaf", parent: branch)

    assert_includes Category.visible, root
    assert_not_includes Category.visible, branch
    assert_not_includes Category.visible, leaf
    branch.update!(hidden: false)
    assert_includes Category.visible, leaf
  end

  test "moving a subtree synchronizes visible and hidden descendant channels" do
    source = Category.create!(name: "Refrigeration", slug: "refrigeration")
    target = Category.create!(name: "Cooking", slug: "cooking-equipment")
    branch = Category.create!(name: "Branch", parent: source)
    hidden = Category.create!(name: "Hidden", parent: branch, hidden: true)
    leaf = Category.create!(name: "Leaf", parent: hidden)
    sku = Sku.create!(category: leaf, status: "active")

    branch.update!(parent: target)
    [branch, hidden, leaf].each do |category|
      assert_equal target.slug, category.reload.category_kind
    end
    assert_equal target.slug, sku.reload.category.category_kind
    assert_equal source.slug, source.reload.category_kind
  end

  test "rolling back a move also rolls back descendant channels" do
    source = Category.create!(name: "Refrigeration", slug: "refrigeration")
    target = Category.create!(name: "Cooking", slug: "cooking-equipment")
    branch = Category.create!(name: "Branch", parent: source)
    leaf = Category.create!(name: "Leaf", parent: branch)

    Category.transaction do
      branch.update!(parent: target)
      raise ActiveRecord::Rollback
    end

    assert_equal source.id, branch.reload.parent_id
    assert_equal source.slug, leaf.reload.category_kind
  end

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
