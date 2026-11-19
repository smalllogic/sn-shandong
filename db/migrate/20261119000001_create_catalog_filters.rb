class CreateCatalogFilters < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_filter_fields do |t|
      t.string :code, null: false
      t.string :label_en, null: false
      t.string :label_zh
      t.string :label_it
      t.string :label_fr
      t.string :kind, null: false
      t.string :unit
      t.text :legacy_names
      t.timestamps
      t.index :code, unique: true
    end

    create_table :category_filters do |t|
      t.references :category, null: false, foreign_key: { on_delete: :cascade }
      t.references :catalog_filter_field, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.boolean :enabled, null: false, default: true
      t.timestamps
      t.index [:category_id, :catalog_filter_field_id], unique: true
    end
  end
end
