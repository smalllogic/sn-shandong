class HomeController < ApplicationController
  before_action :check_submission_rate_limit, only: [:create_contact]

  def index
    @featured_categories = Category.visible.where(featured: true).reorder(featured_position: :asc, id: :desc).with_attached_image
    @site_config = SiteConfig.get
  end

  def all_products
    @kind = params[:kind]
    if params[:q].is_a?(String) && params[:q].present?
      @categories = Category.visible.where(parent_id: nil).includes(children: { children: { children: :children } })
      @skus = Sku.visible
                 .where("LOWER(skus.name) LIKE :query OR LOWER(skus.sku_code) LIKE :query",
                        query: "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].downcase)}%")
                 .includes(:category, images_attachments: :blob)
                 .in_catalog_order
                 .page(params[:page]).per(20)
      render "categories/index"
    else
      @skus_by_category = Sku.visible.in_catalog_order.group_by(&:category_id)
      @categories_by_parent = Category.visible.to_a.group_by(&:parent_id)
      @root_categories = @categories_by_parent.fetch(nil, [])
    end
  end

  def contact
    @contact_message = ContactMessage.new
    if user_signed_in?
      @contact_message.name = current_user.contact_name.presence || current_user.display_name
      @contact_message.email = current_user.email
    end
  end

  def faqs
    @faq_categories = FaqCategory.includes(:faqs).order(position: :asc)
  end


  def privacy
  end


  def customize
  end

  def create_contact
    @contact_message = ContactMessage.new(contact_params)
    if params[:privacy_agreement] != "1"
      @contact_message.errors.add(:base, t("home.contact.form.privacy_error"))
      return render :contact, status: :unprocessable_entity
    end

    unless verify_turnstile(params["cf-turnstile-response"])
      @contact_message.errors.add(:base, t("home.contact.form.verification_failed"))
      return render :contact, status: :unprocessable_entity
    end

    @contact_message.user = current_user if user_signed_in?
    if @contact_message.save
      session[:last_submission_time] = Time.current.to_s
      begin
        # 记录调试信息到日志
        Rails.logger.info "[Mailer Debug] Attempting to send contact notification for Message ID: #{@contact_message.id}"
        Rails.logger.info "[Mailer Debug] From: #{ENV['MAILER_FROM'] || 'onboarding@resend.dev'}"
        Rails.logger.info "[Mailer Debug] API Key exists: #{ENV['RESEND_API_KEY'].present?}"

        # 使用 deliver_now 强制同步发送，以便在日志中捕获即时错误
        NotificationMailer.contact_notification(@contact_message).deliver_now
        
        Rails.logger.info "[Mailer Debug] Mail sent successfully."
      rescue => e
        Rails.logger.error "[Mailer Error] Delivery failed: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.first(10).join("\n")
      end
      redirect_to contact_path, notice: t('home.contact.success_notice')
    else
      render :contact, status: :unprocessable_entity
    end
  end

  def robots
    config = SiteConfig.get
    if config.robots.attached?
      render plain: config.robots.download, content_type: 'text/plain'
    else
      # 默认 robots.txt 内容
      render plain: "User-agent: *\nAllow: /\nDisallow: /admin/\nDisallow: /users/\nDisallow: /up\n\nSitemap: #{root_url}sitemap.xml", content_type: 'text/plain'
    end
  end

  def sitemap
    config = SiteConfig.get
    if config.sitemap.attached?
      render xml: config.sitemap.download
    elsif File.exist?(Rails.root.join('public', 'sitemap.xml'))
      render xml: File.read(Rails.root.join('public', 'sitemap.xml'))
    else
      render xml: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n  <url>\n    <loc>#{root_url}</loc>\n    <priority>1.0</priority>\n  </url>\n</urlset>", status: :not_found
    end
  end

  private

  def verify_turnstile(token)
    return false if token.blank?

    secret_key = ENV.fetch("CLOUDFLARE_TURNSTILE_SECRET_KEY", "1x0000000000000000000000000000000AA")
    uri = URI.parse("https://challenges.cloudflare.com/turnstile/v0/siteverify")
    request_to_verify = Net::HTTP::Post.new(uri)
    request_to_verify.set_form_data(secret: secret_key, response: token, remoteip: request.remote_ip)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5) do |http|
      http.request(request_to_verify)
    end
    return false unless response.is_a?(Net::HTTPSuccess)

    outcome = JSON.parse(response.body)
    outcome.is_a?(Hash) && outcome["success"] == true
  rescue IOError, SystemCallError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError, JSON::ParserError => error
    Rails.logger.warn("Turnstile verification unavailable: #{error.class}")
    false
  end

  def check_submission_rate_limit
    last_submission = session[:last_submission_time]
    if last_submission.present? && Time.parse(last_submission) > 1.minute.ago
      redirect_to contact_path, alert: t('home.submission_limit')
      return
    end
  end

  def contact_params
    params.require(:contact_message).permit(:name, :email, :message)
  end
end
