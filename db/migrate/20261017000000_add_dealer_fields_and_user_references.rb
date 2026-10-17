class AddDealerFieldsAndUserReferences < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :dealer_status, :string, default: "none" unless column_exists?(:users, :dealer_status)
    add_column :users, :company_name, :string unless column_exists?(:users, :company_name)
    add_column :users, :contact_name, :string unless column_exists?(:users, :contact_name)
    add_column :users, :phone, :string unless column_exists?(:users, :phone)
    add_column :users, :country, :string unless column_exists?(:users, :country)
    add_column :users, :dealer_notes, :text unless column_exists?(:users, :dealer_notes)
    add_column :users, :dealer_approved_at, :datetime unless column_exists?(:users, :dealer_approved_at)
    add_index :users, :dealer_status unless index_exists?(:users, :dealer_status)

    add_reference :contact_messages, :user, foreign_key: true, null: true unless column_exists?(:contact_messages, :user_id)
    add_reference :orders, :user, foreign_key: true, null: true unless column_exists?(:orders, :user_id)
    add_column :orders, :message, :text unless column_exists?(:orders, :message)
  end
end
