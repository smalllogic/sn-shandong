class FixRootCategories < ActiveRecord::Migration[8.1]
  def up
    categories = [
      { name: 'Refrigeration', slug: 'refrigeration' },
      { name: 'Stainless steel product', slug: 'stainless-steel-product' },
      { name: 'Stainless steel Sink', slug: 'stainless-steel-sink' },
      { name: 'Cooking Equipment', slug: 'cooking-equipment' },
      { name: 'Food Equipment', slug: 'food-equipment' },
      { name: 'Retail Refrigeration', slug: 'retail-refrigeration' }
    ]

    categories.each_with_index do |cat_data, index|
      category = Category.find_or_initialize_by(slug: cat_data[:slug])
      category.update!(
        name: cat_data[:name],
        parent_id: nil,
        position: index + 1,
        category_kind: cat_data[:slug]
      )
    end
  end

  def down
    # 迁移回退时通常不删除数据，除非特别要求
  end
end
