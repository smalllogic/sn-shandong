class Faq < ApplicationRecord
  belongs_to :faq_category
  validates :question, :answer, presence: true

  def localized_question
    localized_value(:question)
  end

  def localized_answer
    localized_value(:answer)
  end

  private

  def localized_value(attribute)
    suffix = case I18n.locale.to_sym
    when :"zh-CN", :zh then :zh
    when :it then :it
    when :fr then :fr
    end

    translated_value = public_send("#{attribute}_#{suffix}") if suffix
    translated_value.presence || public_send(attribute)
  end
end
