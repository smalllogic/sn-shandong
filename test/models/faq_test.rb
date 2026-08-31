require "test_helper"

class FaqTest < ActiveSupport::TestCase
  setup do
    category = FaqCategory.create!(name: "General")
    @faq = Faq.create!(
      faq_category: category,
      question: "English question?",
      question_zh: "中文问题？",
      question_it: "Domanda italiana?",
      question_fr: "Question française ?",
      answer: "English answer",
      answer_zh: "中文答案",
      answer_it: "Risposta italiana",
      answer_fr: "Réponse française"
    )
  end

  test "returns the question and answer for the current locale" do
    I18n.with_locale(:"zh-CN") do
      assert_equal "中文问题？", @faq.localized_question
      assert_equal "中文答案", @faq.localized_answer
    end

    I18n.with_locale(:it) do
      assert_equal "Domanda italiana?", @faq.localized_question
      assert_equal "Risposta italiana", @faq.localized_answer
    end

    I18n.with_locale(:fr) do
      assert_equal "Question française ?", @faq.localized_question
      assert_equal "Réponse française", @faq.localized_answer
    end
  end

  test "falls back to English when a translation is blank" do
    @faq.update!(question_fr: nil, answer_fr: "")

    I18n.with_locale(:fr) do
      assert_equal "English question?", @faq.localized_question
      assert_equal "English answer", @faq.localized_answer
    end
  end
end
