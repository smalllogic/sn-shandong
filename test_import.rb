require 'csv'
require_relative 'config/environment'

# Create a dummy CSV file
csv_content = CSV.generate(headers: true) do |csv|
  csv << ["SKU名称", "分类ID", "价格", "状态", "排序", "中文名称", "英文名称", "意大利语名称", "法语名称", "中文功能特点", "英文功能特点", "技术规格(JSON)"]
  # Make sure we use a valid leaf category ID. Let's find one first.
  leaf_category = Category.all.select(&:leaf?).first
  if leaf_category
    csv << ["Test SKU 1", leaf_category.id, "10.5", "active", "10", "测试SKU 1", "Test SKU 1", "SKU Test 1", "SKU Test 1", "<li>特点</li>", "<li>Feature</li>", '[{"key":"Color","value":"Red"}]']
    puts "Using leaf category ID: #{leaf_category.id}"
  else
    puts "No leaf category found!"
    exit 1
  end
end

File.write('test_skus.csv', csv_content)

# Run the import service
service = SkuImportService.new('test_skus.csv')
result = service.call

puts "Result: #{result.inspect}"

# Verify if SKU was created
sku = Sku.find_by(name: "Test SKU 1")
if sku
  puts "SKU created successfully!"
  puts "Name ZH: #{sku.name_zh}"
  puts "Rich Text ZH: #{sku.standard_features_zh.to_s}"
  puts "Specs: #{sku.specifications.inspect}"
  sku.destroy
else
  puts "SKU creation failed!"
end

File.delete('test_skus.csv')
File.delete('test_import.rb')
