require "test_helper"

class PostTest < ActiveSupport::TestCase
  setup do
    @post = Post.create!(
      title: "English title",
      title_zh: "中文标题",
      title_it: "Titolo italiano",
      title_fr: "Titre français",
      summary: "English summary",
      summary_zh: "中文简介",
      summary_it: "Riassunto italiano",
      summary_fr: "Résumé français",
      meta_title: "English SEO title",
      meta_title_zh: "中文 SEO 标题",
      status: "draft",
      category: "enterprise_updates",
      content: "English content",
      content_zh: "中文正文",
      content_it: "Contenuto italiano",
      content_fr: "Contenu français"
    )
  end

  test "returns the fields for the current locale" do
    I18n.with_locale(:"zh-CN") do
      assert_equal "中文标题", @post.localized_title
      assert_equal "中文简介", @post.localized_summary
      assert_equal "中文正文", @post.localized_content.to_plain_text
      assert_equal "中文 SEO 标题", @post.localized_meta_title
    end

    I18n.with_locale(:it) do
      assert_equal "Titolo italiano", @post.localized_title
      assert_equal "Riassunto italiano", @post.localized_summary
      assert_equal "Contenuto italiano", @post.localized_content.to_plain_text
    end

    I18n.with_locale(:fr) do
      assert_equal "Titre français", @post.localized_title
      assert_equal "Résumé français", @post.localized_summary
      assert_equal "Contenu français", @post.localized_content.to_plain_text
    end
  end

  test "falls back to English when a translation is blank" do
    @post.update!(title_fr: nil, summary_fr: "", content_fr: nil, meta_title_zh: nil)

    I18n.with_locale(:fr) do
      assert_equal "English title", @post.localized_title
      assert_equal "English summary", @post.localized_summary
      assert_equal "English content", @post.localized_content.to_plain_text
    end

    I18n.with_locale(:"zh-CN") do
      assert_equal "English SEO title", @post.localized_meta_title
    end
  end
end
