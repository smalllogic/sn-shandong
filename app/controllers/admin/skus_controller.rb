class Admin::SkusController < Admin::BaseController
  before_action :set_sku, only: [:show, :edit, :update, :destroy, :delete_image]

  def index
    @q = params[:q]
    @category_id = params[:category_id]
    session[:sku_list_category_id] = @category_id

    @skus = Sku.all.includes(category: :parent, images_attachments: :blob).order(position: :asc, created_at: :desc)

    if @q.present?
      query = "%#{ActiveRecord::Base.sanitize_sql_like(@q.downcase)}%"
      @skus = @skus.where("LOWER(name) LIKE :query OR LOWER(sku_code) LIKE :query", query: query)
    end

    if @category_id.present?
      @skus = @skus.where(category_id: @category_id)
    end

    @categories = Category.joins(:skus).distinct.order(:name)

    respond_to do |format|
      format.html
      format.csv do
        unless current_user.super_admin?
          return redirect_to admin_skus_path, alert: "只有大管理员才能导出 CSV。"
        end
        @export_skus = @skus
        send_data generate_csv(@export_skus), filename: "skus-#{Date.today}.csv"
      end
    end
  end

  def import
  end

  def do_import
    file = params[:file]
    if file.blank?
      flash.now[:alert] = "请选择要上传的 CSV 文件。"
      render :import, status: :unprocessable_entity
      return
    end

    begin
      import_service = SkuImportService.new(file.path)
      result = import_service.call
      
      if result[:success] > 0 || result[:errors].empty?
        notice = "成功导入 #{result[:success]} 条记录。"
        notice += " 失败 #{result[:failed]} 条。" if result[:failed] > 0
        redirect_to admin_skus_path, notice: notice
      else
        flash.now[:alert] = "导入失败：#{result[:errors].join(', ')}"
        render :import, status: :unprocessable_entity
      end
    rescue StandardError => e
      flash.now[:alert] = "解析文件时发生错误：#{e.message}"
      render :import, status: :unprocessable_entity
    end
  end

  def download_template
    headers = [
      "SKU名称", "SKU代码", "分类ID", "价格", "状态", "排序",
      "中文名称", "英文名称", "意大利语名称", "法语名称",
      "中文功能特点", "英文功能特点", "意大利语功能特点", "法语功能特点",
      "技术规格(JSON)",
      "中文SEO标题", "英文SEO标题", "意语SEO标题", "法语SEO标题",
      "中文SEO描述", "英文SEO描述", "意语SEO描述", "法语SEO描述",
      "中文SEO关键词", "英文SEO关键词", "意语SEO关键词", "法语SEO关键词"
    ]
    
    csv_data = CSV.generate(headers: true) do |csv|
      csv << headers
      csv << [
        "示例产品", "SKU-001", "561", "99.99", "active", "1",
        "示例产品(中)", "Sample Product(EN)", "Prodotto di esempio", "Produit exemple",
        "特点1\n特点2", "Feature 1\nFeature 2", "Caratteristica 1\nCaratteristica 2", "Caractéristique 1\nCaractéristique 2",
        '[{"key":"Material","value":"Steel","key_zh":"材质","value_zh":"钢","key_it":"Materiale","value_it":"Acciaio","key_fr":"Matériau","value_fr":"Acier"}]',
        "SEO标题", "SEO Title", "Titolo SEO", "Titre SEO",
        "SEO描述", "SEO Description", "Descrizione SEO", "Description SEO",
        "关键词", "Keywords", "Parole chiave", "Mots-clés"
      ]
    end

    send_data "\xEF\xBB\xBF" + csv_data, filename: "sku_import_template.csv", type: 'text/csv; charset=utf-8; header=present'
  end

  def export
    unless current_user.super_admin?
      return redirect_to admin_skus_path, alert: "只有大管理员才能导出 CSV。"
    end
    @skus = Sku.includes(category: :parent, images_attachments: :blob).order(position: :asc, created_at: :desc)
    send_data generate_csv(@skus), filename: "all-skus-#{Date.today}.csv"
  end


  def update_positions
    unless params[:positions].present?
      return redirect_back fallback_location: admin_skus_path, alert: "未提供有效的排序数据。"
    end

    positions = params[:positions].to_unsafe_h
                                  .transform_keys { |k| Integer(k) rescue nil }
                                  .transform_values { |v| Integer(v) rescue nil }
                                  .reject { |k, v| k.nil? || v.nil? || v < 0 || v > 999_999 }

    positions.each do |sku_id, position|
      Sku.where(id: sku_id).update_all(position: position)
    end

    redirect_back fallback_location: admin_skus_path, notice: "排序权重已更新。"
  end

  def show
  end

  def new
    category_id = params[:category_id]
    category = Category.find_by(id: category_id) if category_id.present?
    
    @sku = Sku.new(category: category)
  end

  def edit
    normalize_specifications
  end

  def create
    begin
      filtered_params = sku_params
      process_specifications(filtered_params)
      # 提取图片位置信息，并从 filtered_params 中删除，防止 UnknownAttributeError
      image_positions = filtered_params.delete(:image_positions)
      
      # 过滤空的图片/文件占位符，防止保存时出现空附件
      # 注意：不要过滤 position 字段，因为 0.blank? 是 true
      # 提取图片/文件参数，用于后续单独处理，避免 Sku.new(params) 可能引起的自动分配
      images = filtered_params.delete(:images)

      @sku = Sku.new(filtered_params)
      if @sku.save
        # 显式使用 attach 附加图片/文件
        @sku.images.attach(images) if images.present?

        update_image_positions(@sku, image_positions)
        redirect_to sku_list_path, notice: "SKU created successfully."
      else
        Rails.logger.error "SKU Create Failed: #{@sku.errors.full_messages.join(', ')}"
        render :new, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "SKU Create Exception: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      @sku ||= Sku.new
      @sku.errors.add(:base, "Save error: #{e.message}.")
      render :new, status: :unprocessable_entity
    end
  end

  def update
    begin
      normalize_specifications
      filtered_params = sku_params
      process_specifications(filtered_params)
      # 提取图片位置信息，并从 filtered_params 中删除，防止 UnknownAttributeError
      image_positions = filtered_params.delete(:image_positions)

      # 如果用户在编辑时没有上传新文件，从 params 中剔除对应键，防止覆盖旧文件
      # 注意：不要过滤 position 字段，因为 0.blank? 是 true
      # 注意：对于 images，如果使用了 config.active_storage.replace_on_assign_to_many = false
      # 那么上传新图片会附加到旧图片。如果上传的是空数组，则不进行任何操作。
      # 提取图片/文件参数，用于后续单独处理，避免 update 方法的全量替换行为
      images = filtered_params.delete(:images)

      if @sku.update(filtered_params)
        # 显式使用 attach 附加图片，确保不替换旧图片
        @sku.images.attach(images) if images.present?

        update_image_positions(@sku, image_positions)
        redirect_to sku_list_path, notice: "SKU updated successfully."
      else
        Rails.logger.error "SKU Update Failed: #{@sku.errors.full_messages.join(', ')}"
        render :edit, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "SKU Update Exception: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      @sku ||= Sku.find(params[:id]) if params[:id]
      @sku.errors.add(:base, "Update error: #{e.message}.") if @sku
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @sku.destroy
    redirect_to sku_list_path, notice: "SKU deleted successfully."
  end

  def delete_image
    return redirect_to sku_list_path, alert: "SKU not found." unless @sku
    
    image = @sku.images.find(params[:image_id])
    image.purge
    redirect_back fallback_location: edit_admin_sku_path(@sku), notice: "Image deleted successfully."
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: edit_admin_sku_path(@sku), alert: "Image not found."
  rescue ActiveStorage::InvariableError
    redirect_back fallback_location: edit_admin_sku_path(@sku), alert: "Invalid file format."
  end

  private

  def generate_csv(skus)
    CSV.generate(headers: true) do |csv|
      # 定义表头
      base_headers = ["ID", "SKU Code", "Position", "Name", "Channel", "Category Path", "Price", "Status", "Image URLs"]
      csv << base_headers + [Sku.human_attribute_name(:standard_features)]

      categories_cache = Category.all.includes(:parent).index_by(&:id)

      skus.each do |sku|
        cat = categories_cache[sku.category_id]
        path_segments = []
        while cat
          path_segments.unshift(cat.name)
          cat = categories_cache[cat.parent_id]
        end
        category_path = path_segments.join(" > ")

        image_urls = sku.images.attached? ? sku.images.map { |img| url_for(img) }.join(",") : ""
        
        row = [
          sku.id, sku.sku_code, sku.position, sku.name, sku.category.category_kind, category_path, sku.price, sku.status,
          image_urls
        ]
        
        csv << row + [sku.standard_features.to_s]
      end
    end
  end

  def sku_list_path
    category_id = session[:sku_list_category_id]
    category_id.present? ? admin_skus_path(category_id: category_id) : admin_skus_path
  end

  def update_image_positions(sku, image_positions)
    return unless image_positions.present?

    valid_ids = sku.images_attachments.pluck(:id)
    image_positions.each do |id, pos|
      parsed_id = Integer(id) rescue nil
      next unless parsed_id && valid_ids.include?(parsed_id)
      parsed_pos = (Integer(pos) rescue 0).clamp(0, 999_999)
      ActiveStorage::Attachment.where(id: parsed_id).update_all(position: parsed_pos)
    end
  end

  def set_sku
    @sku = Sku.find(params[:id])
  end

  def normalize_specifications
    return unless @sku && @sku.specifications.is_a?(Hash)
    
    # 将旧的 Hash 格式 {"key" => "value"} 转换为新格式 [{"key" => "key", "value" => "value", ...}]
    new_specs = @sku.specifications.map do |k, v|
      {
        'key' => k,
        'value' => v,
        'key_zh' => '', 'value_zh' => '',
        'key_it' => '', 'value_it' => '',
        'key_fr' => '', 'value_fr' => ''
      }
    end
    @sku.specifications = new_specs
  end

  def sku_params
    params.require(:sku).permit(
      :name, :sku_code, :name_zh, :name_en, :name_it, :name_fr,
      :category_id, :price, :status, :position,
      :standard_features, :standard_features_zh, :standard_features_it, :standard_features_fr,
      :meta_title, :meta_title_zh, :meta_title_en, :meta_title_it, :meta_title_fr,
      :meta_description, :meta_description_zh, :meta_description_en, :meta_description_it, :meta_description_fr,
      :meta_keywords, :meta_keywords_zh, :meta_keywords_en, :meta_keywords_it, :meta_keywords_fr,
      images: [], image_positions: {},
      specifications: [:key, :value, :key_zh, :value_zh, :key_it, :value_it, :key_fr, :value_fr]
    )
  end

  def process_specifications(filtered_params)
    specs = filtered_params.delete(:specifications)
    if specs.is_a?(Array)
      processed_specs = []
      specs.each do |s|
        # 只要有一个语言的 key 有值，就保留这一行
        if s[:key].present? || s[:key_zh].present? || s[:key_it].present? || s[:key_fr].present?
          processed_specs << {
            key: s[:key].to_s.strip,
            value: s[:value].to_s.strip,
            key_zh: s[:key_zh].to_s.strip,
            value_zh: s[:value_zh].to_s.strip,
            key_it: s[:key_it].to_s.strip,
            value_it: s[:value_it].to_s.strip,
            key_fr: s[:key_fr].to_s.strip,
            value_fr: s[:value_fr].to_s.strip
          }
        end
      end
      filtered_params[:specifications] = processed_specs
    end
  end
end
