class CleanupUnusedSkuFieldsAndTables < ActiveRecord::Migration[8.0]
  def change
    # 删除不再使用的表
    drop_table :a_sku_details, if_exists: true
    drop_table :b_sku_details, if_exists: true
    drop_table :c_sku_details, if_exists: true

    # 删除 skus 表中的冗余字段
    remove_column :skus, :color, :string if column_exists?(:skus, :color)
    remove_column :skus, :standard_features, :text if column_exists?(:skus, :standard_features)
  end
end
