class RemoveProductSpecificationFieldsFromSkus < ActiveRecord::Migration[8.0]
  def change
    remove_column :skus, :product_name, :string
    remove_column :skus, :material, :string
    remove_column :skus, :specification, :string
    remove_column :skus, :moq, :string
    remove_column :skus, :sample_time, :string
    remove_column :skus, :production_lead_time, :string
    remove_column :skus, :packing, :string
    remove_column :skus, :carton_size, :string
    remove_column :skus, :gross_weight, :string

    # 注意：specifications 是 JSONB 字段，在模型层移除 store_accessor 即可，
    # 物理列 specifications 本身保留以备将来使用其他扩展参数。
  end
end
