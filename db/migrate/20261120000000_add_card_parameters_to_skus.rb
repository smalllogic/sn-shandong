class AddCardParametersToSkus < ActiveRecord::Migration[8.1]
  def change
    add_column :skus, :card_parameters_en, :text
    add_column :skus, :card_parameters_zh, :text
    add_column :skus, :card_parameters_it, :text
    add_column :skus, :card_parameters_fr, :text
  end
end
