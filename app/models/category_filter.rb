class CategoryFilter < ApplicationRecord
  belongs_to :category
  belongs_to :catalog_filter_field

  validates :catalog_filter_field_id, uniqueness: { scope: :category_id }
  validates :position, numericality: { only_integer: true, in: 0..9999 }

  scope :enabled, -> { where(enabled: true) }
  scope :in_display_order, -> { order(:position, :id) }
end
