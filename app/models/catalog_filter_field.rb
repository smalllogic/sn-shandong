class CatalogFilterField < ApplicationRecord
  KINDS = {
    "choice" => "选项多选",
    "number" => "数值范围",
    "interval" => "设备范围包含目标值",
    "interval_cover" => "设备范围覆盖整个需求区间",
    "price" => "商品价格范围"
  }.freeze

  has_many :category_filters, dependent: :restrict_with_error

  normalizes :code, with: ->(value) { value.strip.downcase }
  normalizes :unit, with: ->(value) { value.strip.presence }

  validates :code, presence: true, uniqueness: true, format: { with: /\A[a-z][a-z0-9_]*\z/ }, length: { maximum: 48 }
  validates :kind, inclusion: { in: KINDS.keys }
  validates :label_en, presence: true
  validates :label_en, :label_zh, :label_it, :label_fr, length: { maximum: 100 }
  validates :unit, length: { maximum: 20 }
  validates :unit, presence: true, format: { with: /\A[A-Z]{3}\z/, message: "请输入三位大写货币代码，例如 USD" }, if: :price?
  validates :legacy_names, length: { maximum: 2500 }
  validate :validate_source_names
  validate :validate_stable_identity, on: :update

  def price?
    kind == "price"
  end

  def interval?
    %w[interval interval_cover].include?(kind)
  end

  def source_names
    legacy_names.to_s.lines.map { |line| line.strip.downcase }.reject(&:empty?).uniq
  end

  def localized_label
    suffix = { "zh-CN" => "zh", "it" => "it", "fr" => "fr" }[I18n.locale.to_s]
    (self["label_#{suffix}"].presence if suffix) || label_en
  end

  private

  def validate_source_names
    return if price?
    errors.add(:legacy_names, "请每行填写一个规格名称，最多 30 个") unless source_names.size.between?(1, 30)
  end

  def validate_stable_identity
    errors.add(:code, "保存后不能修改") if will_save_change_to_code?
  end
end
