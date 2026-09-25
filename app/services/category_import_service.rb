class CategoryImportService
  require 'csv'

  def initialize(file_path)
    @file_path = file_path
  end

  def call
    success_count = 0
    failed_count = 0
    errors = []

    Category.transaction do
      CSV.foreach(@file_path, headers: true, encoding: 'bom|utf-8') do |row|
        begin
          category_attributes = map_row_to_attributes(row)

          # Slug is portable between servers; use ID only for older templates.
          category = if row["Slug"].present?
            Category.unscoped.find_by(slug: row["Slug"].to_s.strip)
          end

          category ||= Category.unscoped.find_by(id: row["ID"]) if row["ID"].present? && row["Slug"].blank?

          if category
            category.assign_attributes(category_attributes)
          else
            category = Category.new(category_attributes)
          end

          if category.save
            success_count += 1
          else
            failed_count += 1
            errors << "第 #{$. } 行 (#{row['名称(ZH)'] || row['Slug']}): #{category.errors.full_messages.join(', ')}"
          end
        rescue StandardError => e
          failed_count += 1
          errors << "第 #{$. } 行解析错误: #{e.message}"
        end
      end

      raise ActiveRecord::Rollback if failed_count.positive?
    end

    success_count = 0 if failed_count.positive?

    { success: success_count, failed: failed_count, errors: errors, rolled_back: failed_count.positive? }
  end

  private

  def map_row_to_attributes(row)
    parent = if row["父级Slug"].present?
      Category.unscoped.find_by(slug: row["父级Slug"].to_s.strip)
    elsif row["父级ID"].present?
      Category.unscoped.find_by(id: row["父级ID"])
    end

    {
      name_zh: row["名称(ZH)"],
      name_en: row["名称(EN)"],
      name: row["名称(ZH)"] || row["名称(EN)"], # 保证基础 name 不为空
      slug: row["Slug"],
      parent_id: parent&.id || (row["父级ID"] if row["父级Slug"].blank?),
      category_kind: row["分类类型"],
      position: row["排序"] || 0,
      hidden: row["是否显示"] == '否',
      featured: row["是否推荐"] == '是',
      featured_position: row["推荐排序"] || 0,
      # SEO 字段（可选扩展）
      meta_title_zh: row["中文SEO标题"],
      meta_title_en: row["英文SEO标题"],
      meta_description_zh: row["中文SEO描述"],
      meta_description_en: row["英文SEO描述"],
      meta_keywords_zh: row["中文SEO关键词"],
      meta_keywords_en: row["英文SEO关键词"]
    }.compact
  end
end
