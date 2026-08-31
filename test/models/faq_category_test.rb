require "test_helper"

class FaqCategoryTest < ActiveSupport::TestCase
  test "returns the localized name with English fallback" do
    category = FaqCategory.create!(
      name: "General",
      name_zh: "常见问题",
      name_it: "Domande generali",
      name_fr: "Questions générales"
    )

    I18n.with_locale(:"zh-CN") { assert_equal "常见问题", category.localized_name }
    I18n.with_locale(:it) { assert_equal "Domande generali", category.localized_name }
    I18n.with_locale(:fr) { assert_equal "Questions générales", category.localized_name }

    category.update!(name_fr: nil)
    I18n.with_locale(:fr) { assert_equal "General", category.localized_name }
  end
end
