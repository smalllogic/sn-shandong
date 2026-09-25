require "test_helper"
require "csv"
require "digest"
require "json"
require "stringio"
require "zip"

class CatalogTransferTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "exports and imports categories and skus by stable keys without duplicates" do
    root, leaf, sku = create_catalog
    archive = CatalogTransfer::Export.new.call

    leaf.update!(name_en: "Changed locally")
    sku.update!(name: "Changed locally", price: 9)

    result = CatalogTransfer::Import.new(StringIO.new(archive)).call
    assert_equal({ categories: 2, skus: 1 }, result)
    assert_equal "Leaf", leaf.reload.name_en
    assert_equal "Product", sku.reload.name
    assert_equal 25, sku.price
    assert_equal leaf.id, sku.category_id

    CatalogTransfer::Import.new(StringIO.new(archive)).call
    assert_equal 2, Category.unscoped.count
    assert_equal 1, Sku.count
    assert_equal root.id, leaf.reload.parent_id
  end

  test "a sku failure rolls back category updates in the same archive" do
    _root, leaf, _sku = create_catalog
    archive = CatalogTransfer::Export.new.call
    entries = read_entries(archive)
    entries[CatalogTransfer::CATEGORY_FILE] = change_csv(entries[CatalogTransfer::CATEGORY_FILE]) do |rows|
      rows.find { |row| row["slug"] == "leaf" }["name_en"] = "Imported change"
    end
    entries[CatalogTransfer::SKU_FILE] = change_csv(entries[CatalogTransfer::SKU_FILE]) do |rows|
      rows.first["category_slug"] = "missing-leaf"
    end
    manifest = JSON.parse(entries[CatalogTransfer::MANIFEST_FILE])
    [CatalogTransfer::CATEGORY_FILE, CatalogTransfer::SKU_FILE].each do |filename|
      manifest["sha256"][filename] = Digest::SHA256.hexdigest(entries[filename])
    end
    entries[CatalogTransfer::MANIFEST_FILE] = manifest.to_json

    error = assert_raises(CatalogTransfer::Error) do
      CatalogTransfer::Import.new(StringIO.new(write_entries(entries))).call
    end
    assert_match(/missing-leaf/, error.message)
    assert_equal "Leaf", leaf.reload.name_en
    assert_equal 1, Sku.count
  end

  test "category slugs resolve sku links when database IDs differ" do
    old_root, old_leaf, old_sku = create_catalog
    archive = CatalogTransfer::Export.new.call
    old_sku.destroy!
    old_leaf.destroy!
    old_root.destroy!
    Category.create!(name_en: "Ventilation", slug: "ventilation")

    CatalogTransfer::Import.new(StringIO.new(archive)).call
    imported_leaf = Category.unscoped.find_by!(slug: "leaf")
    assert_not_equal old_leaf.id, imported_leaf.id
    assert_equal imported_leaf.id, Sku.find_by!(sku_code: "SKU-1").category_id
    assert_equal "refrigeration", imported_leaf.parent.slug
  end

  test "models reject orphan categories and repeated sku codes" do
    root, leaf, _sku = create_catalog
    orphan = Category.new(name_en: "Orphan", slug: "orphan", parent_id: 999_999)
    assert_not orphan.valid?
    assert_includes orphan.errors[:parent_id], "父分类不存在"

    duplicate = Sku.new(sku_code: " SKU-1 ", name: "Duplicate", category: leaf, position: 1)
    assert_not duplicate.valid?
    assert_equal "SKU-1", duplicate.sku_code
    assert_includes duplicate.errors[:sku_code], "has already been taken"
    assert root.valid?
  end

  test "accepts a finder recompressed archive with one folder and macos metadata" do
    _root, leaf, _sku = create_catalog
    entries = read_entries(CatalogTransfer::Export.new.call)
    wrapped = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("catalog/")
      entries.each do |name, contents|
        zip.put_next_entry("catalog/#{name}")
        zip.write(contents)
      end
      zip.put_next_entry("__MACOSX/catalog/._categories.csv")
      zip.write("finder metadata")
      zip.put_next_entry("catalog/.DS_Store")
      zip.write("finder metadata")
    end.string

    assert_equal({ categories: 2, skus: 1 }, CatalogTransfer::Import.new(StringIO.new(wrapped)).call)
    assert_equal leaf.id, Sku.find_by!(sku_code: "SKU-1").category_id
  end

  test "explains why an old archive without a manifest cannot be imported" do
    legacy = write_entries("categories.csv" => "", "skus.csv" => "", "README.txt" => "old export")
    error = assert_raises(CatalogTransfer::Error) do
      CatalogTransfer::Import.new(StringIO.new(legacy)).call
    end
    assert_match(/旧版 ZIP.*manifest.json/, error.message)
  end

  private

  def create_catalog
    root = Category.create!(name_en: "Refrigeration", slug: "refrigeration")
    leaf = Category.create!(name_en: "Leaf", slug: "leaf", parent: root)
    sku = Sku.create!(sku_code: "SKU-1", name: "Product", category: leaf,
                      price: 25, position: 1, status: "active",
                      specifications: [{ "key" => "Power", "value" => "100 W" }],
                      standard_features: "<p>Feature</p>")
    [root, leaf, sku]
  end

  def read_entries(archive)
    result = nil
    Zip::File.open_buffer(StringIO.new(archive)) do |zip|
      result = zip.entries.to_h { |entry| [entry.name, entry.get_input_stream.read] }
    end
    result
  end

  def write_entries(entries)
    Zip::OutputStream.write_buffer do |zip|
      entries.each do |name, content|
        zip.put_next_entry(name)
        zip.write(content)
      end
    end.string
  end

  def change_csv(contents)
    rows = CSV.parse(contents.dup.force_encoding(Encoding::UTF_8).delete_prefix("\uFEFF"), headers: true)
    yield rows
    "\uFEFF" + CSV.generate { |csv|
      csv << rows.headers
      rows.each { |row| csv << row.fields }
    }
  end
end
