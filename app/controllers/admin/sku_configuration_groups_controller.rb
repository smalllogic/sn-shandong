class Admin::SkuConfigurationGroupsController < Admin::BaseController
  before_action :load_sku
  before_action :load_group, only: %i[edit update destroy]

  def index
    @groups = @sku.configuration_groups.includes(options: { image_attachment: :blob })
  end

  def new
    @group = @sku.configuration_groups.build
    @group.options.build
  end

  def edit
  end

  def create
    @group = @sku.configuration_groups.build(group_params)
    if @group.save
      redirect_to admin_sku_sku_configuration_groups_path(@sku), notice: "配置组已添加。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @group.update(group_params)
      redirect_to admin_sku_sku_configuration_groups_path(@sku), notice: "配置组已更新。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @group.destroy!
    redirect_to admin_sku_sku_configuration_groups_path(@sku), notice: "配置组已删除。", status: :see_other
  end

  private

  def load_sku
    @sku = Sku.find(params[:sku_id])
  end

  def load_group
    @group = @sku.configuration_groups.find(params[:id])
  end

  def group_params
    params.require(:sku_configuration_group).permit(
      :name_en, :name_zh, :name_it, :name_fr, :currency, :position, :enabled,
      options_attributes: %i[id name_en name_zh name_it name_fr model_code surcharge position enabled image remove_image _destroy]
    )
  end
end
