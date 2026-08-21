class ReorganizeSkusForNewProductTypes < ActiveRecord::Migration[8.1]
  def change
    # 删除旧的、不再需要的 SKU 字段
    remove_column :skus, :brim_length, :string
    remove_column :skus, :closure, :string
    remove_column :skus, :closure_type, :string
    remove_column :skus, :fabric, :string
    remove_column :skus, :head_circumference, :string
    remove_column :skus, :item, :string
    remove_column :skus, :item_no, :string
    remove_column :skus, :profile, :string
    remove_column :skus, :visor, :string
    remove_column :skus, :embroidery_print, :string
    remove_column :skus, :unit_dimensions, :string
    
    # 确保共享字段存在 (有些可能已经存在，有些可能需要调整)
    # 已经存在的字段: name, product_name, material, specification, moq, sample_time, 
    # production_lead_time, packing, carton_size, gross_weight, price
    
    # 添加 JSONB 字段用于存储差异化参数
    add_column :skus, :specifications, :jsonb, default: {}
  end
end
