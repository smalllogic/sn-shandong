class OrderItem < ApplicationRecord
  MAX_QUANTITY = 9_999

  belongs_to :order
  belongs_to :sku
  validates :quantity, numericality: { only_integer: true, in: 1..MAX_QUANTITY }

  before_create :snapshot_product

  def product_snapshot?
    !sku_name_snapshot.nil? && !sku_code_snapshot.nil?
  end

  def product_name
    sku_name_snapshot || sku&.localized_name
  end

  def product_code
    sku_code_snapshot || sku&.sku_code
  end

  private

  def snapshot_product
    self.sku_name_snapshot = sku.localized_name.to_s
    self.sku_code_snapshot = sku.sku_code.to_s
  end
end
