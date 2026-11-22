class ReconcileBusinessRules < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE users SET role = 'super_admin' WHERE admin = TRUE"
    execute <<~SQL
      UPDATE users
      SET dealer_status = CASE WHEN dealer_status IN ('pending', 'approved', 'rejected') THEN dealer_status ELSE 'approved' END,
          role = 'user'
      WHERE role = 'dealer'
    SQL
    execute "UPDATE users SET role = 'user' WHERE role IS NULL OR role NOT IN ('user', 'editor', 'admin', 'super_admin')"
    execute "UPDATE users SET dealer_status = 'none' WHERE dealer_status IS NULL OR dealer_status NOT IN ('none', 'pending', 'approved', 'rejected')"
    execute "UPDATE users SET dealer_approved_at = NULL WHERE dealer_status <> 'approved'"

    %i[sku_configuration_groups sku_configuration_options].each do |table|
      add_column table, :transfer_key, :uuid, default: -> { "gen_random_uuid()" }, null: false
      add_index table, :transfer_key, unique: true
    end

    add_column :orders, :submission_key, :string
    add_index :orders, :submission_key, unique: true
    add_column :order_items, :sku_name_snapshot, :string
    add_column :order_items, :sku_code_snapshot, :string
    add_column :site_configs, :catalog_currency, :string, limit: 3, default: "USD", null: false
    execute <<~SQL
      UPDATE site_configs
      SET catalog_currency = (
        SELECT MIN(unit) FROM catalog_filter_fields WHERE kind = 'price' AND unit ~ '^[A-Z]{3}$'
      )
      WHERE (SELECT COUNT(DISTINCT unit) FROM catalog_filter_fields WHERE kind = 'price' AND unit ~ '^[A-Z]{3}$') = 1
    SQL

    execute <<~SQL
      UPDATE skus SET sku_code = 'SKU-' || gen_random_uuid()::text
      WHERE sku_code IS NULL OR btrim(sku_code) = ''
    SQL
    execute "UPDATE skus SET sku_code = btrim(sku_code) WHERE sku_code <> btrim(sku_code)"
    change_column_null :skus, :sku_code, false
    remove_index :skus, :sku_code
    add_index :skus, :sku_code, unique: true
    remove_index :categories, :slug
    add_index :categories, :slug, unique: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Account roles and missing SKU codes were normalized"
  end
end
