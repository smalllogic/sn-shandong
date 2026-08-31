class Post < ApplicationRecord
  has_rich_text :content
  has_rich_text :content_zh
  has_rich_text :content_it
  has_rich_text :content_fr

  has_one_attached :cover_image do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 400, 300 ], format: :webp, saver: { quality: 80 }
    attachable.variant :large, resize_to_limit: [ 1200, 800 ], format: :webp, saver: { quality: 85 }
  end

  CATEGORIES = %w[enterprise_updates industry_news].freeze

  validates :title, presence: true
  validates :status, inclusion: { in: %w[draft published] }
  validates :category, presence: true, inclusion: { in: CATEGORIES }

  scope :published, -> { where(status: "published").order(published_at: :desc) }
  scope :enterprise_updates, -> { where(category: "enterprise_updates") }
  scope :industry_news, -> { where(category: "industry_news") }

  def published?
    status == "published"
  end

  def increment_views!
    increment!(:views_count)
  end

  def localized_title
    localized_value(:title)
  end

  def localized_summary
    localized_value(:summary)
  end

  def localized_content
    localized_value(:content)
  end

  def localized_meta_title
    localized_value(:meta_title)
  end

  def localized_meta_description
    localized_value(:meta_description)
  end

  def localized_meta_keywords
    localized_value(:meta_keywords)
  end

  private

  # English uses the original fields so existing posts remain valid. Missing
  # translations fall back to English instead of rendering an empty article.
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
