class SkuConfigurationOption < ApplicationRecord
  include ConfigurationDisplayName

  belongs_to :sku_configuration_group, inverse_of: :options
  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_limit: [144, 144], format: :webp, saver: { quality: 80 }
    attachable.variant :large, resize_to_limit: [1200, 1200], format: :webp, saver: { quality: 85 }
  end
  attribute :remove_image, :boolean, default: false

  normalizes :model_code, with: ->(value) { value.strip.presence }
  validates :model_code, length: { maximum: 100 }
  validates :surcharge, numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000_000 }, allow_nil: true
  validates :position, numericality: { only_integer: true, in: 0..9999 }
  before_validation :detach_image_if_requested
  validate :validate_image

  private

  def detach_image_if_requested
    self.image = nil if remove_image && !attachment_changes.key?("image")
  end

  def validate_image
    return unless image.attached?
    unless image.content_type.in?(%w[image/jpeg image/png image/webp image/gif image/bmp])
      errors.add(:image, "请上传 JPEG、PNG、WebP、GIF 或 BMP 图片")
    end
    errors.add(:image, "图片不能超过 10 MB") if image.byte_size > 10.megabytes
  end
end
