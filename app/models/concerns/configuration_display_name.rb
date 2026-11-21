module ConfigurationDisplayName
  extend ActiveSupport::Concern

  included do
    validates :name_en, presence: true
    validates :name_en, :name_zh, :name_it, :name_fr, length: { maximum: 120 }
  end

  def localized_name
    case I18n.locale.to_s
    when "zh-CN" then name_zh.presence || name_en
    when "it" then name_it.presence || name_en
    when "fr" then name_fr.presence || name_en
    else name_en
    end
  end
end
