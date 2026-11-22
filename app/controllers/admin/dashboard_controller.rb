class Admin::DashboardController < Admin::BaseController
  before_action :require_super_admin, only: [:catalog_export, :catalog_import]

  def index
    @users_count = Rails.cache.fetch("admin_users_count", expires_in: 1.hour) { User.count }
    @total_skus = Rails.cache.fetch("admin_total_skus_count", expires_in: 1.hour) { Sku.count }
    @active_skus = Rails.cache.fetch("admin_active_skus_count", expires_in: 1.hour) { Sku.where(status: 'active').count }
    @messages_count = Rails.cache.fetch("admin_messages_count", expires_in: 1.hour) { ContactMessage.count }
    @today_visits = Rails.cache.fetch("admin_today_visits_count", expires_in: 10.minutes) do
      VisitRecord.where("visit_time >= ?", Time.current.beginning_of_day).count
    end
    @total_visits = Rails.cache.fetch("admin_total_visits_count", expires_in: 1.hour) { VisitRecord.count }
    
    # 诊断信息
    @storage_writable = File.writable?("/app/storage") rescue false
    @vips_installed = system("vips --version") rescue false
  end

  def catalog_export
    send_data CatalogTransfer::Export.new.call,
      filename: "category-sku-#{Time.current.strftime('%Y%m%d-%H%M%S')}.zip",
      type: "application/zip"
  rescue CatalogTransfer::Error => e
    redirect_to admin_root_path, alert: "无法导出：#{e.message}"
  end

  def catalog_import
    importer = CatalogTransfer::Import.new(params[:file])
    if params[:preview].present?
      summary = importer.preview
      return redirect_to admin_root_path, notice: "导入预检：新增分类 #{summary[:new_categories]}、更新分类 #{summary[:updated_categories]}，新增 SKU #{summary[:new_skus]}、更新 SKU #{summary[:updated_skus]}，缺少的分类依赖 #{summary[:missing_categories]}。#{summary[:includes_extras] ? '含扩展资料。' : '仅基础资料。'} 确认后请重新选择文件并导入。"
    end
    result = importer.call
    redirect_to admin_root_path, notice: "导入完成：分类 #{result[:categories]} 条，SKU #{result[:skus]} 条。"
  rescue CatalogTransfer::Error => e
    redirect_to admin_root_path, alert: "导入失败，所有改动已回滚：#{e.message}"
  rescue StandardError => e
    Rails.logger.error("Catalog import failed: #{e.class}: #{e.message}")
    redirect_to admin_root_path, alert: "导入失败，所有改动已回滚。请检查服务器日志。"
  end

end
