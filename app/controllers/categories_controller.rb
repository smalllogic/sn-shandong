class CategoriesController < ApplicationController
  def index
    @kind = params[:kind]
    
    # 频道标识与分类模型允许的顶级分类保持一致。
    unless @kind.nil? || Category.root_slugs.include?(@kind)
      redirect_to categories_path, alert: "无效的分类频道"
      return
    end

    @categories = Category.visible.where(parent_id: nil).includes(children: { children: { children: :children } })
    
    if @kind.present?
      @categories = @categories.where(category_kind: @kind)
    end
    
    if params[:category_id].present?
      begin
        @current_category = Category.visible.includes(parent: { parent: :parent }).find_by(slug: params[:category_id])
        @current_category ||= Category.visible.includes(parent: { parent: :parent }).find(params[:category_id])
        
        @skus = @current_category.all_descendant_skus.visible.includes(:category, images_attachments: :blob)
        
        if params[:q].present?
          query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].downcase)}%"
          @skus = @skus.where("LOWER(skus.name) LIKE :query OR LOWER(skus.sku_code) LIKE :query", query: query)
        end

        @skus = @skus.page(params[:page]).per(20)
      rescue ActiveRecord::RecordNotFound
        redirect_to categories_path, alert: "未找到指定的分类"
        return
      end
    else
      @skus = Sku.visible.joins(:category).includes(:category, images_attachments: :blob).in_catalog_order
      
      if @kind.present?
        @skus = @skus.where(categories: { category_kind: @kind })
      end

      if params[:q].present?
        query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].downcase)}%"
        @skus = @skus.where("LOWER(skus.name) LIKE :query OR LOWER(skus.sku_code) LIKE :query", query: query)
      end

      @skus = @skus.page(params[:page]).per(20)
    end
  end

  def show
    @category = Category.visible.find_by(slug: params[:id]) || Category.visible.find_by(id: params[:id])
    return redirect_to categories_path, alert: "未找到指定的分类" unless @category
    redirect_to categories_path(category_id: @category.slug.presence || @category.id)
  end
end
