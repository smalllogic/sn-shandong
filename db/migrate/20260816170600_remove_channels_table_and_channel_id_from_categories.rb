class RemoveChannelsTableAndChannelIdFromCategories < ActiveRecord::Migration[7.1]
  def change
    # 删除 channels 表
    # 首先检查表是否存在，以防万一
    if table_exists?(:channels)
      drop_table :channels
    end

    # 从 categories 表中移除 channel_id 字段
    if column_exists?(:categories, :channel_id)
      remove_column :categories, :channel_id, :integer
    end
  end
end
