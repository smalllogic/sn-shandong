class Admin::CategoriesController < Admin::BaseController
  before_action :set_category, only: [:show, :edit, :update, :destroy]

  def index
    @categories = Category.unscoped.where(parent_id: nil).order(:position, :id).includes(:children)
  end

  def export
    @categories = Category.unscoped.order(:id)
    
    respond_to do |format|
      format.csv do
        filename = "categories-#{Time.now.strftime('%Y%m%d%H%M%S')}.csv"
        
        headers = %w[ID 名称(ZH) 名称(EN) Slug 父级ID 父级Slug 分类类型 排序 是否显示 是否推荐 推荐排序 中文SEO标题 英文SEO标题 中文SEO描述 英文SEO描述 中文SEO关键词 英文SEO关键词]
        
        csv_data = CSV.generate(headers: true) do |csv|
          csv << headers
          @categories.each do |category|
            csv << [
              category.id,
              category.name_zh,
              category.name_en,
              category.slug,
              category.parent_id,
              category.parent&.slug,
              category.category_kind,
              category.position,
              category.hidden ? '否' : '是',
              category.featured ? '是' : '否',
              category.featured_position,
              category.meta_title_zh,
              category.meta_title_en,
              category.meta_description_zh,
              category.meta_description_en,
              category.meta_keywords_zh,
              category.meta_keywords_en
            ]
          end
        end
        
        send_data "\xEF\xBB\xBF" + csv_data, filename: filename, type: 'text/csv; charset=utf-8; header=present'
      end
    end
  end

  def import
  end

  def do_import
    session[:category_import_completed] = false
    file = params[:file]
    if file.blank?
      flash.now[:alert] = "请选择要上传的 CSV 文件。"
      render :import, status: :unprocessable_entity
      return
    end

    begin
      import_service = CategoryImportService.new(file.path)
      result = import_service.call

      if result[:success] > 0 && result[:failed].zero?
        session[:category_import_completed] = true
        notice = "成功导入 #{result[:success]} 条记录。"
        notice += " 失败 #{result[:failed]} 条。" if result[:failed] > 0
        redirect_to admin_categories_path, notice: notice
      else
        session[:category_import_completed] = false
        flash.now[:alert] = "导入失败：#{result[:errors].join(', ')}"
        render :import, status: :unprocessable_entity
      end
    rescue StandardError => e
      flash.now[:alert] = "解析文件时发生错误：#{e.message}"
      render :import, status: :unprocessable_entity
    end
  end

  def download_template
    headers = %w[ID 名称(ZH) 名称(EN) Slug 父级ID 父级Slug 分类类型 排序 是否显示 是否推荐 推荐排序 中文SEO标题 英文SEO标题 中文SEO描述 英文SEO描述 中文SEO关键词 英文SEO关键词]

    csv_data = CSV.generate(headers: true) do |csv|
      csv << headers
      csv << [
        "", "冷链设备", "Refrigeration", "refrigeration", "", "", "refrigeration", "1", "是", "否", "0",
        "冷链设备", "Refrigeration", "专业冷链设备描述", "Professional Refrigeration Description", "冷链,设备", "Refrigeration,Equipment"
      ]
    end

    send_data "\xEF\xBB\xBF" + csv_data, filename: "category_import_template.csv", type: 'text/csv; charset=utf-8; header=present'
  end

  def show
  end

  def new
    if params[:parent_id].present?
      parent = Category.find(params[:parent_id])
      @category = Category.new(parent_id: parent.id)
    else
      @category = Category.new
    end
  end

  def edit
  end

  def create
    @category = Category.new(category_params)
    if @category.save
      redirect_to admin_categories_path, notice: '分类创建成功。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @category.update(category_params)
      redirect_to admin_categories_path, notice: '分类更新成功。'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @category.parent_id.nil? && Category::ROOT_CATEGORIES.key?(@category.slug)
      redirect_to admin_categories_path, alert: '顶级分类不可删除。'
    else
      @category.destroy
      redirect_to admin_categories_path, notice: '分类已删除。'
    end
  end

  private

  def set_category
    @category = Category.find_by!(slug: params[:id])
  rescue ActiveRecord::RecordNotFound
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(
      :name, :name_zh, :name_en, :name_it, :name_fr,
      :slug, :parent_id, :category_kind, :hidden, :position, :featured, :featured_position, :image, :banner,
      :meta_title, :meta_title_zh, :meta_title_en, :meta_title_it, :meta_title_fr,
      :meta_description, :meta_description_zh, :meta_description_en, :meta_description_it, :meta_description_fr,
      :meta_keywords, :meta_keywords_zh, :meta_keywords_en, :meta_keywords_it, :meta_keywords_fr,
      :keywords, :keywords_zh, :keywords_en, :keywords_it, :keywords_fr
    )
  end
end
