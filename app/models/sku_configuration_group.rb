class SkuConfigurationGroup < ApplicationRecord
  include ConfigurationDisplayName

  belongs_to :sku
  has_many :options, -> { order(:position, :id) }, class_name: "SkuConfigurationOption",
    inverse_of: :sku_configuration_group, dependent: :destroy

  accepts_nested_attributes_for :options, allow_destroy: true
  normalizes :currency, with: ->(value) { value.strip.upcase.presence }
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }, allow_nil: true
  validates :position, numericality: { only_integer: true, in: 0..9999 }
  validate :validate_options

  def available_options
    enabled? ? options.select(&:enabled?) : []
  end

  private

  def validate_options
    kept = options.reject(&:marked_for_destruction?)
    if enabled? && kept.none?(&:enabled?)
      errors.add(:options, "启用的配置组至少需要一个启用的选项")
    end
    if currency.blank? && kept.any? { |option| option.surcharge.present? }
      errors.add(:currency, "填写加价金额时，请设置币种")
    end
  end
end
