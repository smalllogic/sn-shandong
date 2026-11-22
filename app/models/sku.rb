class Sku < ApplicationRecord
  CARD_PARAMETER_FIELDS = %i[card_parameters_en card_parameters_zh card_parameters_it card_parameters_fr].freeze
  MAX_CARD_PARAMETER_LINES = 4
  MAX_CARD_PARAMETER_LENGTH = 80

  normalizes(*CARD_PARAMETER_FIELDS, with: ->(value) { value.lines.map(&:strip).reject(&:empty?).join("\n").presence })
  validate :validate_card_parameters

  before_validation :normalize_sku_code
  validates :status, inclusion: { in: %w[draft active archived] }
  validates :price, numericality: { greater_than_or_equal_to: 0, less_than: 100_000_000 }, allow_nil: true
  validate :validate_specifications
  after_commit :clear_dashboard_cache

  belongs_to :category
  has_many :configuration_groups, -> { order(:position, :id) }, class_name: "SkuConfigurationGroup",
    inverse_of: :sku, dependent: :destroy
  scope :visible, -> { where(status: 'active', category_id: Category.visible.select(:id)) }
  scope :in_catalog_order, -> { order(position: :asc, created_at: :desc, id: :desc) }

  def available_configuration_groups
    configuration_groups.select { |group| group.available_options.any? }
  end
  has_many_attached :images do |attachable|
    attachable.variant :thumb, resize_to_limit: [200, 200], format: :webp, saver: { quality: 80 }
    attachable.variant :medium, resize_to_limit: [800, 800], format: :webp, saver: { quality: 85 }
    attachable.variant :large, resize_to_limit: [1200, 1200], format: :webp, saver: { quality: 85 }
  end
  
  def sorted_images
    images_attachments.includes(:blob).order(:position, :created_at)
  end
  has_rich_text :standard_features
  has_rich_text :standard_features_zh
  has_rich_text :standard_features_it
  has_rich_text :standard_features_fr

  def localized_name
    case I18n.locale.to_sym
    when :en
      name_en.presence || name
    when :it
      name_it.presence || name
    when :fr
      name_fr.presence || name
    when :"zh-CN", :zh
      name_zh.presence || name
    else
      name
    end
  end

  def localized_card_parameters
    locale = I18n.locale.to_s.split("-").first
    columns = CARD_PARAMETER_FIELDS.map(&:to_s)
    preferred = "card_parameters_#{locale}"
    columns = [preferred] + columns if columns.include?(preferred)
    columns.uniq.filter_map { |column| self[column].presence }.first.to_s.lines.map(&:chomp)
  end

  def localized_meta_title
    case I18n.locale.to_sym
    when :en
      meta_title_en.presence || meta_title
    when :it
      meta_title_it.presence || meta_title
    when :fr
      meta_title_fr.presence || meta_title
    when :"zh-CN", :zh
      meta_title_zh.presence || meta_title
    else
      meta_title
    end
  end

  def localized_meta_description
    case I18n.locale.to_sym
    when :en
      meta_description_en.presence || meta_description
    when :it
      meta_description_it.presence || meta_description
    when :fr
      meta_description_fr.presence || meta_description
    when :"zh-CN", :zh
      meta_description_zh.presence || meta_description
    else
      meta_description
    end
  end

  def localized_meta_keywords
    case I18n.locale.to_sym
    when :en
      meta_keywords_en.presence || meta_keywords
    when :it
      meta_keywords_it.presence || meta_keywords
    when :fr
      meta_keywords_fr.presence || meta_keywords
    when :"zh-CN", :zh
      meta_keywords_zh.presence || meta_keywords
    else
      meta_keywords
    end
  end

  def localized_standard_features
    case I18n.locale.to_sym
    when :en
      standard_features
    when :it
      standard_features_it.presence || standard_features
    when :fr
      standard_features_fr.presence || standard_features
    when :"zh-CN", :zh
      standard_features_zh.presence || standard_features
    else
      standard_features
    end
  end

  def localized_specifications
    specification_rows.grep(Hash).map do |spec|
      case I18n.locale.to_sym
      when :en
        { key: spec['key'], value: spec['value'] }
      when :it
        { key: spec['key_it'].presence || spec['key'], value: spec['value_it'].presence || spec['value'] }
      when :fr
        { key: spec['key_fr'].presence || spec['key'], value: spec['value_fr'].presence || spec['value'] }
      when :"zh-CN", :zh
        { key: spec['key_zh'].presence || spec['key'], value: spec['value_zh'].presence || spec['value'] }
      else
        { key: spec['key'], value: spec['value'] }
      end
    end.reject { |s| s[:key].blank? }
  end
  def specification_rows
    self.class.specification_rows(specifications)
  end

  def self.specification_rows(values)
    case values
    when Hash then values.map { |key, value| { "key" => key, "value" => value } }
    when Array then values
    else []
    end
  end

  validates :position, numericality: { only_integer: true }
  validates :sku_code, presence: true, uniqueness: true
  validate :category_must_be_leaf
  validate :images_must_be_bmp_or_png_jpg_images

  # specifications 字段保留，作为 JSON 数组存储
  # 不再使用 store_accessor，因为内容是动态且多语言的数组

  private

  def validate_card_parameters
    CARD_PARAMETER_FIELDS.each do |field|
      lines = self[field].to_s.lines
      if lines.size > MAX_CARD_PARAMETER_LINES || lines.any? { |line| line.chomp.length > MAX_CARD_PARAMETER_LENGTH }
        errors.add(field, "最多 #{MAX_CARD_PARAMETER_LINES} 行，每行最多 #{MAX_CARD_PARAMETER_LENGTH} 个字符")
      end
    end
  end

  def normalize_sku_code
    self.sku_code = sku_code.to_s.strip.presence || "SKU-#{SecureRandom.uuid}"
  end

  def validate_specifications
    return unless will_save_change_to_specifications?
    return if specifications.is_a?(Hash)
    return if specifications.is_a?(Array) && specifications.all? { |row| row.is_a?(Hash) }

    errors.add(:specifications, "必须为规格对象组成的数组")
  end

  def images_must_be_bmp_or_png_jpg_images
    return unless images.attached?

    images.each do |image|
      unless image.content_type.in?(%w[image/jpeg image/jpg image/png image/gif image/webp image/bmp])
        errors.add(:images, "Must be image files (JPEG, PNG, GIF, WebP, BMP). '#{image.filename}' is #{image.content_type}")
      end

      if image.byte_size > 10.megabytes
        errors.add(:images, "File '#{image.filename}' is too large (max 10MB). Current size: #{(image.byte_size / 1.0.megabyte).round(2)}MB")
      end
    end
  end

  def category_must_be_leaf
    return if category.nil?

    unless category.leaf?
      errors.add(:category_id, "SKU can only be assigned to leaf categories.")
    end
  end

  def clear_dashboard_cache
    Rails.cache.delete("admin_total_skus_count")
    Rails.cache.delete("admin_active_skus_count")
  end
end
