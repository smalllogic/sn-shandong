module CatalogTransfer
  class Error < StandardError; end

  FORMAT = "sinower-category-sku".freeze
  VERSION = 1
  MAX_ARCHIVE_BYTES = 50.megabytes
  MAX_ENTRY_BYTES = 100.megabytes
  MAX_ROWS = 100_000
  CATEGORY_FILE = "categories.csv".freeze
  SKU_FILE = "skus.csv".freeze
  MANIFEST_FILE = "manifest.json".freeze
  FILES = [CATEGORY_FILE, SKU_FILE, MANIFEST_FILE].freeze

  CATEGORY_ATTRIBUTES = %w[
    name name_zh name_en name_it name_fr category_kind position hidden featured featured_position
    meta_title meta_title_zh meta_title_en meta_title_it meta_title_fr
    meta_description meta_description_zh meta_description_en meta_description_it meta_description_fr
    meta_keywords meta_keywords_zh meta_keywords_en meta_keywords_it meta_keywords_fr
    keywords keywords_zh keywords_en keywords_it keywords_fr
  ].freeze
  CATEGORY_HEADERS = (["slug", "parent_slug"] + CATEGORY_ATTRIBUTES).freeze

  SKU_ATTRIBUTES = %w[
    name name_zh name_en name_it name_fr price status position specifications
    meta_title meta_title_zh meta_title_en meta_title_it meta_title_fr
    meta_description meta_description_zh meta_description_en meta_description_it meta_description_fr
    meta_keywords meta_keywords_zh meta_keywords_en meta_keywords_it meta_keywords_fr
  ].freeze
  RICH_TEXT_ATTRIBUTES = %w[
    standard_features standard_features_zh standard_features_it standard_features_fr
  ].freeze
  SKU_HEADERS = (["sku_code", "category_slug"] + SKU_ATTRIBUTES + RICH_TEXT_ATTRIBUTES).freeze
end
