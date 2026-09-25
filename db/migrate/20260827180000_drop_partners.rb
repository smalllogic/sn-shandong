class DropPartners < ActiveRecord::Migration[8.1]
  def change
    drop_table :partners, if_exists: true do |t|
      t.string :name
      t.timestamps
    end
  end
end
