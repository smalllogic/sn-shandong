require "csv"
require "zip"

class AdminDataTransferExport
  CATEGORY_HEADERS = %w[
    ID 名称(ZH) 名称(EN) Slug 父级ID 父级Slug 分类类型 排序 是否显示 是否推荐 推荐排序
    中文SEO标题 英文SEO标题 中文SEO描述 英文SEO描述 中文SEO关键词 英文SEO关键词
  ].freeze

  SKU_HEADERS = [
    "SKU名称", "SKU代码", "分类ID", "价格", "状态", "排序", "分类Slug",
    "中文名称", "英文名称", "意大利语名称", "法语名称",
    "中文功能特点", "英文功能特点", "意大利语功能特点", "法语功能特点", "技术规格(JSON)",
    "中文SEO标题", "英文SEO标题", "意语SEO标题", "法语SEO标题",
    "中文SEO描述", "英文SEO描述", "意语SEO描述", "法语SEO描述",
    "中文SEO关键词", "英文SEO关键词", "意语SEO关键词", "法语SEO关键词"
  ].freeze

  def call
    buffer = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("categories.csv")
      zip.write utf8_csv(category_csv)
      zip.put_next_entry("skus.csv")
      zip.write utf8_csv(sku_csv)
      zip.put_next_entry("README.txt")
      zip.write "先导入 categories.csv，再导入 skus.csv。SKU 按分类 Slug 关联；分类及 SKU 图片附件不包含在此数据包中。\n"
    end
    buffer.string
  end

  private

  def category_csv
    CSV.generate(headers: true) do |csv|
      csv << CATEGORY_HEADERS
      Category.unscoped.includes(:parent).order(:id).find_each do |category|
        csv << [
          category.id, category.name_zh, category.name_en, category.slug, category.parent_id, category.parent&.slug,
          category.category_kind, category.position, category.hidden ? "否" : "是", category.featured ? "是" : "否",
          category.featured_position, category.meta_title_zh, category.meta_title_en,
          category.meta_description_zh, category.meta_description_en, category.meta_keywords_zh, category.meta_keywords_en
        ]
      end
    end
  end

  def sku_csv
    CSV.generate(headers: true) do |csv|
      csv << SKU_HEADERS
      Sku.includes(:category, :rich_text_standard_features, :rich_text_standard_features_zh,
                   :rich_text_standard_features_it, :rich_text_standard_features_fr).order(:id).find_each do |sku|
        csv << [
          sku.name, sku.sku_code, sku.category_id, sku.price, sku.status, sku.position, sku.category&.slug,
          sku.name_zh, sku.name_en, sku.name_it, sku.name_fr,
          rich_text_html(sku.standard_features_zh), rich_text_html(sku.standard_features),
          rich_text_html(sku.standard_features_it), rich_text_html(sku.standard_features_fr),
          sku.specifications.to_json,
          sku.meta_title_zh, sku.meta_title_en, sku.meta_title_it, sku.meta_title_fr,
          sku.meta_description_zh, sku.meta_description_en, sku.meta_description_it, sku.meta_description_fr,
          sku.meta_keywords_zh, sku.meta_keywords_en, sku.meta_keywords_it, sku.meta_keywords_fr
        ]
      end
    end
  end

  def rich_text_html(rich_text)
    rich_text&.body&.to_html.to_s
  end

  def utf8_csv(csv)
    "\xEF\xBB\xBF" + csv
  end
end
