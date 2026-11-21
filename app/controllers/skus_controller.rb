class SkusController < ApplicationController
  def show
    @sku = Sku.visible.includes(category: { parent: { parent: :parent } }).find_by(id: params[:id])
    
    if @sku.nil?
      redirect_to products_path, alert: t('categories.no_skus_title')
      return
    end

    @kind = @sku.category.category_kind
    @configuration_groups = @sku.configuration_groups.includes(options: { image_attachment: :blob }).select do |group|
      group.available_options.any?
    end
  end
end
