class AddSkuCodeToSkus < ActiveRecord::Migration[8.1]
  def change
    add_column :skus, :sku_code, :string
    add_index :skus, :sku_code
  end
end
