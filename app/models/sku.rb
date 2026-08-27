class Sku < ApplicationRecord
  after_commit :clear_dashboard_cache

  belongs_to :category
  has_many_attached :images do |attachable|
    attachable.variant :thumb, resize_to_limit: [200, 200], format: :webp, saver: { quality: 80 }
    attachable.variant :medium, resize_to_limit: [800, 800], format: :webp, saver: { quality: 85 }
    attachable.variant :large, resize_to_limit: [1200, 1200], format: :webp, saver: { quality: 85 }
  end
  
  def sorted_images
    images_attachments.includes(:blob).order(:position, :created_at)
  end
  has_rich_text :standard_features

  validates :name, presence: true
  validates :position, numericality: { only_integer: true }
  validate :category_must_be_leaf
  validate :images_must_be_bmp_or_png_jpg_images

  # specifications 字段保留但目前没有映射的 accessors
  # 使用 store_accessor 映射 specifications 中的字段，或者使用 jsonb 的灵活特性
  store_accessor :specifications

  private

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
