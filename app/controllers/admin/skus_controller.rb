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
    end
  end



  def import_card_parameters
    count = SkuCardParametersImport.new(params[:file]).call
    redirect_to admin_skus_path, notice: "已更新 #{count} 件商品的卡片参数。", status: :see_other
  rescue SkuCardParametersImport::Error => e
    redirect_to admin_skus_path, alert: e.message, status: :see_other
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
  end

  def create
    @sku = Sku.new
    save_sku(:new, "SKU created successfully.")
  end

  def update
    save_sku(:edit, "SKU updated successfully.")
  end

  def destroy
    @sku.destroy!
    redirect_to sku_list_path, notice: "SKU deleted successfully."
  rescue ActiveRecord::InvalidForeignKey
    redirect_to sku_list_path, alert: "该 SKU 已有询价记录，请归档以保留历史。", status: :see_other
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

  def save_sku(template, notice)
    attributes = sku_params
    uploads = Array(attributes.delete(:images)).reject(&:blank?)
    positions = attributes.delete(:image_positions)
    process_specifications(attributes)
    @sku.assign_attributes(attributes)
    batch = AttachmentUploadBatch.new
    staged_images = uploads.map do |upload|
      blob = ActiveStorage::Blob.build_after_unfurling(io: upload.open, filename: upload.original_filename,
        content_type: upload.content_type)
      [blob, upload]
    end
    @sku.images = @sku.images.blobs + staged_images.map(&:first) if staged_images.any?
    saved = false

    Sku.transaction(requires_new: true) do
      if @sku.save
        staged_images.each { |blob, upload| batch.upload(blob, upload.open) }
        update_image_positions(@sku, positions)
        saved = true
      end
    end

    if saved
      redirect_to sku_list_path, notice: notice
    else
      render template, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    batch&.cleanup_failed_uploads
    @sku.errors.add(:sku_code, "已被其他商品使用")
    render template, status: :unprocessable_entity
  rescue StandardError => error
    batch&.cleanup_failed_uploads
    Rails.logger.error("SKU save failed: #{error.class}: #{error.message}")
    @sku.errors.add(:base, "保存失败，请核对资料和图片后重试。")
    render(@sku.persisted? ? :edit : template, status: :unprocessable_entity)
  end

  def sku_params
    params.require(:sku).permit(
      :name, :sku_code, :name_zh, :name_en, :name_it, :name_fr,
      *Sku::CARD_PARAMETER_FIELDS,
      :category_id, :price, :status, :position, :edit_specifications,
      :standard_features, :standard_features_zh, :standard_features_it, :standard_features_fr,
      :meta_title, :meta_title_zh, :meta_title_en, :meta_title_it, :meta_title_fr,
      :meta_description, :meta_description_zh, :meta_description_en, :meta_description_it, :meta_description_fr,
      :meta_keywords, :meta_keywords_zh, :meta_keywords_en, :meta_keywords_it, :meta_keywords_fr,
      images: [], image_positions: {},
      specifications: [:original_index, :key, :value, :key_zh, :value_zh, :key_it, :value_it, :key_fr, :value_fr]
    )
  end

  def process_specifications(filtered_params)
    editing_specs = filtered_params.delete(:edit_specifications) == "1"
    specs = filtered_params.delete(:specifications)
    specs = [] if specs.nil? && editing_specs
    if specs.is_a?(Array)
      processed_specs = []
      specs.each do |s|
        # 只要有一个语言的 key 有值，就保留这一行
        if s[:key].present? || s[:key_zh].present? || s[:key_it].present? || s[:key_fr].present?
          original = @sku.specification_rows[s[:original_index].to_i] if s[:original_index].to_s.match?(/\A[0-9]+\z/)
          values = {
            key: s[:key].to_s.strip,
            value: s[:value].to_s.strip,
            key_zh: s[:key_zh].to_s.strip,
            value_zh: s[:value_zh].to_s.strip,
            key_it: s[:key_it].to_s.strip,
            value_it: s[:value_it].to_s.strip,
            key_fr: s[:key_fr].to_s.strip,
            value_fr: s[:value_fr].to_s.strip
          }.stringify_keys
          processed_specs << (original.is_a?(Hash) ? original.merge(values) : values)
        end
      end
      filtered_params[:specifications] = processed_specs
    end
  end
end
