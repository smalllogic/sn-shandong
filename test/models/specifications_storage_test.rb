require "test_helper"

class SpecificationsStorageTest < ActiveSupport::TestCase
  test "migration converts populated json to jsonb and can run on existing jsonb" do
    require Rails.root.join("db/migrate/20261119000000_standardize_specifications_as_jsonb")
    category = Category.create!(name: "Refrigeration", slug: "refrigeration")
    values = [{"capacity_l" => 500}, [{"key" => "容量", "value" => "500 L"}]]
    products = values.map { |value| Sku.create!(category: category, specifications: value) }
    connection = ActiveRecord::Base.connection
    connection.execute("ALTER TABLE skus ALTER COLUMN specifications DROP DEFAULT")
    connection.execute("ALTER TABLE skus ALTER COLUMN specifications TYPE json USING specifications::json")
    connection.schema_cache.clear!

    migration = StandardizeSpecificationsAsJsonb.new
    ActiveRecord::Migration.suppress_messages { migration.migrate(:up) }
    connection.schema_cache.clear!
    Sku.reset_column_information
    assert_equal "jsonb", Sku.columns_hash.fetch("specifications").sql_type
    assert_equal values, products.map { |sku| sku.reload.specifications }
    ActiveRecord::Migration.suppress_messages { migration.migrate(:up) }
    assert_equal values, products.map { |sku| sku.reload.specifications }
  ensure
    connection&.schema_cache&.clear!
    Sku.reset_column_information
  end

  test "specifications use native PostgreSQL jsonb and preserve legacy shapes" do
    assert_equal "PostgreSQL", ActiveRecord::Base.connection.adapter_name
    assert_equal "jsonb", Sku.columns_hash.fetch("specifications").sql_type
    category = Category.create!(name: "Refrigeration", slug: "refrigeration")
    values = [{}, {"capacity_l" => 500, "has_wheels" => false},
              [{"key" => "Capacity", "value" => "500 L", "key_zh" => "容量"}]]
    values.each do |value|
      sku = Sku.create!(category: category, specifications: value)
      assert_equal value, sku.reload.specifications
    end
    sku = Sku.where("specifications @> ?::jsonb", {capacity_l: 500}.to_json).sole
    assert_equal 500, sku.specifications.fetch("capacity_l")
  end
end
