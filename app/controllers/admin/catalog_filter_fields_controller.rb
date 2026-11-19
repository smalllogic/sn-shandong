class Admin::CatalogFilterFieldsController < Admin::BaseController
  before_action :load_field, only: %i[edit update destroy]

  def index
    @fields = CatalogFilterField.order(:label_en).includes(:category_filters)
  end

  def new
    @field = CatalogFilterField.new(kind: "choice")
    load_specification_examples
  end

  def edit
    load_specification_examples
  end

  def create
    @field = CatalogFilterField.new(field_params)
    if @field.save
      redirect_to admin_catalog_filter_fields_path, notice: "筛选字段已创建。请在分类的筛选设置中启用。"
    else
      load_specification_examples
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @field.update(field_params)
      redirect_to admin_catalog_filter_fields_path, notice: "筛选字段已更新。"
    else
      load_specification_examples
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @field.destroy
      redirect_to admin_catalog_filter_fields_path, notice: "筛选字段已删除。", status: :see_other
    else
      redirect_to admin_catalog_filter_fields_path, alert: "请先从使用它的分类中移除该字段。", status: :see_other
    end
  end

  private

  def load_field
    @field = CatalogFilterField.find(params[:id])
  end

  def field_params
    params.require(:catalog_filter_field).permit(:code, :label_en, :label_zh, :label_it, :label_fr, :kind, :unit, :legacy_names)
  end

  def load_specification_examples
    @examples = Sku.connection.select_all(<<~SQL)
      SELECT legacy.name, MIN(legacy.raw) AS example, COUNT(DISTINCT skus.id) AS quantity
      FROM skus CROSS JOIN LATERAL (#{CatalogFilterValues::LEGACY_VALUES}) legacy
      WHERE legacy.name IS NOT NULL AND legacy.name <> '' AND legacy.raw IS NOT NULL
      GROUP BY legacy.name ORDER BY quantity DESC, legacy.name LIMIT 40
    SQL
  end
end
