class StandardizeSpecificationsAsJsonb < ActiveRecord::Migration[8.1]
  def up
    unless connection.adapter_name == "PostgreSQL"
      raise "This application requires PostgreSQL for JSONB specifications."
    end

    return if connection.columns(:skus).find { |column| column.name == "specifications" }.sql_type == "jsonb"

    change_column_default :skus, :specifications, nil
    change_column :skus, :specifications, :jsonb, using: "specifications::jsonb"
    change_column_default :skus, :specifications, {}
  end

  def down
    change_column_default :skus, :specifications, nil
    change_column :skus, :specifications, :json, using: "specifications::json"
    change_column_default :skus, :specifications, {}
  end
end
