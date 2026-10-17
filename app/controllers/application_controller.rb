class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern unless Rails.env.test?

  before_action :track_visitor
  before_action :set_site_config
  before_action :configure_permitted_parameters, if: :devise_controller?
  around_action :switch_locale
  helper_method :locale_switch_path

  def after_sign_in_path_for(resource)
    if resource.admin_role?
      admin_root_path
    elsif resource.dealer? || resource.dealer_pending? || resource.dealer_applicant?
      dealer_root_path
    else
      root_path
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    root_path
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:apply_dealer, :company_name, :contact_name, :phone, :country, :dealer_notes])
    devise_parameter_sanitizer.permit(:account_update, keys: [:company_name, :contact_name, :phone, :country, :dealer_notes])
  end

  private

  def switch_locale(&action)
    locale = admin_request? ? I18n.default_locale : requested_locale
    session[:locale] = locale.to_s unless admin_request?
    I18n.with_locale(locale, &action)
  end

  def requested_locale
    candidate = params[:locale].presence || session[:locale] || I18n.default_locale
    I18n.available_locales.map(&:to_s).include?(candidate.to_s) ? candidate : I18n.default_locale
  end

  def admin_request?
    request.path.start_with?("/admin", "/users", "/dealer")
  end

  def locale_switch_path(locale)
    query = (request.query_parameters || {}).merge(locale: locale)
    query.present? ? "#{request.path}?#{query.to_query}" : request.path
  end

  def set_site_config
    @site_config = SiteConfig.get
  end

  def track_visitor
    # 忽略健康检查
    path = request.path
    return if path == "/up"
    
    # 使用 session 标记避免同一个会话频繁查询数据库
    return if session[:vrecord_tracked] && session[:vrecord_last_check] && Time.parse(session[:vrecord_last_check]) > 1.hour.ago

    # 确保 session 加载
    session_id = session.id.to_s
    return if session_id.blank?

    # 尝试获取真实客户端 IP
    if cookies[:ip_tracking_allowed] == "false"
      real_ip = "0000.0000.0000"
    else
      forwarded_for = request.env['HTTP_X_FORWARDED_FOR']
      real_ip = if forwarded_for.present?
                  forwarded_for.split(',').first&.strip
                else
                  request.env['HTTP_X_REAL_IP'] || request.remote_ip
                end
    end

    last_visit = VisitRecord.where(session_id: session_id)
                            .where("visit_time > ?", 3.hours.ago)
                            .order(visit_time: :desc)
                            .first

    if last_visit.nil?
      VisitRecord.create(
        session_id: session_id,
        ip: real_ip,
        user_agent: request.user_agent,
        visit_time: Time.current,
        path: path
      )
    end

    # 标记本小时已检查，减少数据库压力
    session[:vrecord_tracked] = true
    session[:vrecord_last_check] = Time.current.to_s
  end

end
