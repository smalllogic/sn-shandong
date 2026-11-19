class Admin::CategoryFiltersController < Admin::BaseController
  before_action :load_category
  before_action :load_filter, only: %i[edit update destroy]
  before_action :load_fields, only: %i[new edit create update]

  def index
    @filters = @category.category_filters.in_display_order.includes(:catalog_filter_field)
    scope = @category.all_descendant_skus.visible
    @visible_total = scope.count
    @coverage = @filters.to_h do |filter|
      [filter.id, CatalogFilterValues.new(filter.catalog_filter_field).count(scope)]
    end
  end

  def new
    @filter = @category.category_filters.build
  end

  def edit
  end

  def create
    @filter = @category.category_filters.build(filter_params)
    if @filter.save
      redirect_to admin_category_category_filters_path(@category), notice: "筛选项已添加。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @filter.update(filter_params)
      redirect_to admin_category_category_filters_path(@category), notice: "筛选项已更新。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @filter.destroy!
    redirect_to admin_category_category_filters_path(@category), notice: "已从此集合页移除筛选项。", status: :see_other
  end

  private

  def load_category
    @category = Category.find_by(slug: params[:category_id]) || Category.find(params[:category_id])
  end

  def load_filter
    @filter = @category.category_filters.find(params[:id])
  end

  def load_fields
    @fields = CatalogFilterField.order(:label_en)
  end

  def filter_params
    params.require(:category_filter).permit(:catalog_filter_field_id, :position, :enabled)
  end
end
