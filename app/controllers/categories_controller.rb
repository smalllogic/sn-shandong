class CategoriesController < ApplicationController
  def index
    @kind = params[:kind]
    
    # 频道标识与分类模型允许的顶级分类保持一致。
    unless @kind.nil? || Category.root_slugs.include?(@kind)
      redirect_to categories_path, alert: "无效的分类频道"
      return
    end

    @categories = Category.visible.roots.includes(children: { children: { children: :children } })
    @categories = @categories.where(slug: @kind) if @kind
    if params[:category_id].present?
      @current_category = find_visible_category(params[:category_id])
      if @current_category.nil? || (@kind && @current_category.ancestors_and_self.first.slug != @kind)
        return redirect_to categories_path, alert: "未找到指定的分类"
      end
    end

    collection = @current_category || (@categories.find_by(slug: @kind) if @kind)
    scope = if collection
      collection.all_descendant_skus.visible
    elsif @kind
      Sku.none
    else
      Sku.visible.in_catalog_order
    end
    if params[:q].is_a?(String) && params[:q].present?
      query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].downcase)}%"
      scope = scope.where("LOWER(skus.name) LIKE :query OR LOWER(skus.sku_code) LIKE :query", query: query)
    end

    @catalog_filters = CatalogFilterQuery.new(scope, collection, params[:filters])
    @skus = @catalog_filters.results.includes(:category, images_attachments: :blob).page(params[:page]).per(20)
  end

  def show
    @category = Category.visible.find_by(slug: params[:id]) || Category.visible.find_by(id: params[:id])
    return redirect_to categories_path, alert: "未找到指定的分类" unless @category
    redirect_to categories_path(category_id: @category.slug.presence || @category.id)
  end

  private

  def find_visible_category(value)
    return unless value.is_a?(String)
    categories = Category.visible.includes(parent: { parent: :parent })
    categories.find_by(slug: value) || categories.find_by(id: value)
  end
end
