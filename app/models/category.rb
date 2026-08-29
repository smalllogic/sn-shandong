class Category < ApplicationRecord
  ROOT_CATEGORIES = {
    'refrigeration' => 'Refrigeration',
    'stainless-steel-product' => 'Stainless steel product',
    'stainless-steel-sink' => 'Stainless steel Sink',
    'cooking-equipment' => 'Cooking Equipment',
    'food-equipment' => 'Food Equipment',
    'retail-refrigeration' => 'Retail Refrigeration',
    'ventilation' => 'Ventilation'
  }.freeze

  def self.root_slugs
    ROOT_CATEGORIES.keys
  end
  has_many :children, -> { unscoped.order(:position, :id) }, class_name: "Category", foreign_key: :parent_id, dependent: :destroy
  belongs_to :parent, class_name: "Category", optional: true
  has_many :skus, dependent: :destroy
  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_limit: [300, 300], format: :webp, saver: { quality: 80 }
    attachable.variant :featured, resize_to_limit: [600, 800], format: :webp, saver: { quality: 85 }
  end

  has_one_attached :banner do |attachable|
    attachable.variant :large, resize_to_limit: [1920, 600], format: :webp, saver: { quality: 85 }
  end

  default_scope { order(:position, :id) }

  validates :name, presence: true
  validates :keywords, length: { maximum: 255 }
  before_validation :generate_slug, if: -> { slug.blank? }
  before_validation :sync_category_kind
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "只能包含小写字母、数字和连字符" }
  
  scope :visible, -> { where(hidden: false) }
  scope :roots, -> { where(parent_id: nil) }

  after_commit :clear_cache

  def to_param
    slug.presence || id.to_s
  end
  validate :root_category_slug_and_kind_consistency, if: -> { parent_id.nil? }
  validate :prevent_root_slug_change_if_has_children, if: -> { parent_id.nil? && !new_record? }
  validate :validate_root_category_slug, if: -> { parent_id.nil? }

  def validate_root_category_slug
    if !ROOT_CATEGORIES.key?(slug)
      errors.add(:slug, "顶级分类必须是预定义的 7 类之一: #{ROOT_CATEGORIES.keys.join(', ')}")
    end
  end

  def leaf?
    children.empty?
  end

  def depth
    parent ? parent.depth + 1 : 0
  end

  def all_descendant_skus
    if leaf?
      skus.order(position: :asc, created_at: :desc)
    else
      Sku.where(category_id: all_descendant_ids + [ id ]).order(position: :asc, created_at: :desc)
    end
  end

  def all_descendant_ids
    # Fetch all visible categories once and group them by parent_id to avoid N+1 queries
    all_visible = Category.unscoped.visible.select(:id, :parent_id).to_a
    children_map = all_visible.group_by(&:parent_id)
    
    desc_ids = []
    stack = children_map[id] || []
    
    while stack.any?
      child = stack.pop
      desc_ids << child.id
      stack.concat(children_map[child.id] || [])
    end
    desc_ids
  end

  def ancestors_and_self
    res = [ self ]
    node = self
    while node.parent
      node = node.parent
      res.unshift(node)
    end
    res
  end

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

  def localized_keywords
    case I18n.locale.to_sym
    when :en
      keywords_en.presence || keywords
    when :it
      keywords_it.presence || keywords
    when :fr
      keywords_fr.presence || keywords
    when :"zh-CN", :zh
      keywords_zh.presence || keywords
    else
      keywords
    end
  end

  private

  def generate_slug
    return if name.blank?
    self.slug = name.parameterize if slug.blank?
  end

  def sync_category_kind
    if parent_id.nil?
      # 顶级分类，强制 category_kind 等于 slug
      self.category_kind = slug if slug.present?
    else
      # 子分类，继承父分类的 category_kind
      self.category_kind = parent.category_kind if parent
    end
  end

  def root_category_slug_and_kind_consistency
    if slug.present? && category_kind.present? && slug != category_kind
      errors.add(:category_kind, "顶级分类的频道标识必须与其路径(slug)一致")
    end
  end

  def prevent_root_slug_change_if_has_children
    if slug_changed? && children.exists?
      errors.add(:slug, "该分类下已有子项，不可更改路径标识，以免影响子项频道属性")
    end
  end

  def clear_cache
    Rails.cache.delete("categories_for_kind_#{category_kind}") if category_kind.present?
  end

  def leaf_category_constraint_for_parent
    return if parent_id.nil?

    if parent.skus.exists?
      errors.add(:parent_id, "该父分类下已有 SKU，无法在此添加子分类。")
    end
  end

  def consistent_category_kind
    if parent && category_kind != parent.category_kind
      errors.add(:category_kind, "必须与父分类的频道一致")
    end
  end
end
