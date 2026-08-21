class NotificationMailer < ApplicationMailer
  default from: ENV.fetch("MAILER_FROM", "Sinower <onboarding@resend.dev>")

  def contact_notification(contact_message)
    # 强制在发送前再次确保 API Key 被注入
    Resend.api_key = ENV["RESEND_API_KEY"] if ENV["RESEND_API_KEY"].present?
    
    @contact_message = contact_message
    recipients = ENV.fetch("CONTACT_FORM_TO", "info@skyrainbow.com.cn").split(",")
    
    mail(
      to: recipients,
      subject: "New Contact Message from #{@contact_message.name}"
    )
  end
end
