class DropHomeProducts < ActiveRecord::Migration[7.1]
  def change
    drop_table :home_products do |t|
      t.boolean "active"
      t.datetime "created_at", null: false
      t.string "link"
      t.integer "position"
      t.integer "row"
      t.string "title"
      t.datetime "updated_at", null: false
    end
  end
end
