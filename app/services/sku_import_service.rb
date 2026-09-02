class SkuImportService
  require 'csv'

  def initialize(file_path)
    @file_path = file_path
  end

  def call
    success_count = 0
    failed_count = 0
    errors = []

    CSV.foreach(@file_path, headers: true, encoding: 'bom|utf-8') do |row|
      begin
        sku_attributes = map_row_to_attributes(row)
        sku = Sku.new(sku_attributes)
        
        # 处理 Rich Text
        # 如果包含换行符，将其转换为 <br> 以在富文本编辑器中保持换行
        sku.standard_features = format_rich_text(row["英文功能特点"]) if row["英文功能特点"].present?
        sku.standard_features_zh = format_rich_text(row["中文功能特点"]) if row["中文功能特点"].present?
        sku.standard_features_it = format_rich_text(row["意大利语功能特点"]) if row["意大利语功能特点"].present?
        sku.standard_features_fr = format_rich_text(row["法语功能特点"]) if row["法语功能特点"].present?

        if sku.save
          success_count += 1
        else
          failed_count += 1
          error_msg = sku.errors.full_messages.join(', ')
          if sku.errors[:category_id].any?
            category = Category.find_by(id: row["分类ID"])
            if category.nil?
              error_msg = "分类ID #{row["分类ID"]} 不存在"
            elsif !category.leaf?
              error_msg = "分类 '#{category.name}' (ID: #{category.id}) 不是末级分类，SKU 只能绑定到末级分类"
            end
          end
          errors << "第 #{$. } 行: #{error_msg}"
        end
      rescue StandardError => e
        failed_count += 1
        errors << "第 #{$. } 行解析错误: #{e.message}"
      end
    end

    { success: success_count, failed: failed_count, errors: errors }
  end

  private

  def map_row_to_attributes(row)
    {
      name: row["SKU名称"],
      sku_code: row["SKU代码"],
      category_id: row["分类ID"],
      price: row["价格"],
      status: row["状态"] || 'draft',
      position: row["排序"] || 0,
      name_zh: row["中文名称"],
      name_en: row["英文名称"],
      name_it: row["意大利语名称"],
      name_fr: row["法语名称"],
      meta_title_zh: row["中文SEO标题"],
      meta_title_en: row["英文SEO标题"],
      meta_title_it: row["意语SEO标题"],
      meta_title_fr: row["法语SEO标题"],
      meta_description_zh: row["中文SEO描述"],
      meta_description_en: row["英文SEO描述"],
      meta_description_it: row["意语SEO描述"],
      meta_description_fr: row["法语SEO描述"],
      meta_keywords_zh: row["中文SEO关键词"],
      meta_keywords_en: row["英文SEO关键词"],
      meta_keywords_it: row["意语SEO关键词"],
      meta_keywords_fr: row["法语SEO关键词"],
      specifications: parse_specifications(row["技术规格(JSON)"])
    }
  end

  def parse_specifications(json_str)
    return [] if json_str.blank?
    begin
      JSON.parse(json_str)
    rescue JSON::ParserError
      []
    end
  end

  def format_rich_text(text)
    return text if text.blank?
    # 如果文本中包含换行符但没有 HTML 标签，则尝试转换换行符为 <br>
    if text.include?("\n") && !text.include?("<")
      text.gsub("\n", "<br>")
    else
      text
    end
  end
end
