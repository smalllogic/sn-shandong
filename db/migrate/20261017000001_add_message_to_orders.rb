class AddMessageToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :message, :text unless column_exists?(:orders, :message)
  end
end
