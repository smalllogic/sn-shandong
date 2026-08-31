class FaqCategory < ApplicationRecord
  has_many :faqs, -> { order(position: :asc) }, dependent: :destroy
  validates :name, presence: true

  def localized_name
    suffix = case I18n.locale.to_sym
    when :"zh-CN", :zh then :zh
    when :it then :it
    when :fr then :fr
    end

    translated_name = public_send("name_#{suffix}") if suffix
    translated_name.presence || name
  end
end
