class CreateSkuConfigurations < ActiveRecord::Migration[8.1]
  def change
    create_table :sku_configuration_groups do |t|
      t.references :sku, null: false, foreign_key: { on_delete: :cascade }
      t.string :name_en, null: false
      t.string :name_zh
      t.string :name_it
      t.string :name_fr
      t.string :currency, limit: 3
      t.integer :position, null: false, default: 0
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end

    create_table :sku_configuration_options do |t|
      t.references :sku_configuration_group, null: false, foreign_key: { on_delete: :cascade }
      t.string :name_en, null: false
      t.string :name_zh
      t.string :name_it
      t.string :name_fr
      t.string :model_code
      t.decimal :surcharge, precision: 12, scale: 2
      t.integer :position, null: false, default: 0
      t.boolean :enabled, null: false, default: true
      t.timestamps
      t.check_constraint "surcharge >= 0", name: "sku_configuration_options_nonnegative_surcharge"
    end

    add_column :order_items, :configuration_snapshot, :jsonb, default: [], null: false
  end
end
