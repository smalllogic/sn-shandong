module ApplicationHelper
  def categories_for_kind(kind)
    Rails.cache.fetch("categories_for_kind_#{kind}", expires_in: 12.hours) do
      Category.visible.where(category_kind: kind, parent_id: nil).includes(children: { children: { children: { children: :children } } }).to_a
    end
  end

  def channel_path(kind, options = {})
    # 尝试查找对应的硬编码路由
    helper_method = "#{kind}_channel_path"
    if respond_to?(helper_method)
      send(helper_method, options)
    else
      # 如果没有硬编码路由，则使用通用分类路由，并带上 kind 参数
      categories_path(options.merge(kind: kind))
    end
  end
end
