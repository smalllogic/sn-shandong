require "csv"
require "digest"
require "json"
require "set"
require "zip"

module CatalogTransfer
  class Export
    def call
      categories = Category.unscoped.includes(:parent).to_a
      skus = Sku.includes(:category, *RICH_TEXT_ATTRIBUTES.map { |name| "rich_text_#{name}".to_sym }).to_a
      validate_source!(categories, skus)

      category_csv = csv(CATEGORY_HEADERS) do |writer|
        categories.sort_by(&:id).each do |category|
          writer << [category.slug, category.parent&.slug] + CATEGORY_ATTRIBUTES.map { |name| category.public_send(name) }
        end
      end
      sku_csv = csv(SKU_HEADERS) do |writer|
        skus.sort_by(&:id).each do |sku|
          writer << [sku.sku_code, sku.category.slug] +
            SKU_ATTRIBUTES.map { |name| name == "specifications" ? sku.specifications.to_json : sku.public_send(name) } +
            RICH_TEXT_ATTRIBUTES.map { |name| sku.public_send(name)&.body&.to_html }
        end
      end

      manifest = {
        format: FORMAT, version: VERSION,
        counts: { CATEGORY_FILE => categories.size, SKU_FILE => skus.size },
        sha256: { CATEGORY_FILE => Digest::SHA256.hexdigest(category_csv), SKU_FILE => Digest::SHA256.hexdigest(sku_csv) }
      }.to_json

      if category_csv.bytesize > MAX_ENTRY_BYTES || sku_csv.bytesize > MAX_ENTRY_BYTES
        raise Error, "数据量超过单个 CSV 的 100 MB 上限，无法生成可导入的数据包。"
      end

      archive = Zip::OutputStream.write_buffer do |zip|
        { CATEGORY_FILE => category_csv, SKU_FILE => sku_csv, MANIFEST_FILE => manifest }.each do |name, contents|
          zip.put_next_entry(name)
          zip.write(contents)
        end
      end.string
      raise Error, "ZIP 超过 50 MB，无法生成可导入的数据包。" if archive.bytesize > MAX_ARCHIVE_BYTES
      archive
    end

    private

    def csv(headers)
      "\uFEFF" + CSV.generate { |writer|
        writer << headers
        yield writer
      }
    end

    def validate_source!(categories, skus)
      if categories.size > MAX_ROWS || skus.size > MAX_ROWS
        raise Error, "记录数超过每份 CSV 的 #{MAX_ROWS} 行上限，无法生成可导入的数据包。"
      end

      categories_by_id = categories.index_by(&:id)
      repeated = categories.group_by { |category| category.slug.to_s.strip }.find { |slug, records| slug.empty? || records.size > 1 }
      raise Error, "分类 Slug 为空或重复：#{repeated.first.inspect}。请先修复分类数据。" if repeated

      categories.each do |category|
        if category.parent_id && !categories_by_id.key?(category.parent_id)
          raise Error, "分类 #{category.slug} 的父分类不存在。"
        end
        seen = {}
        node = category
        while node
          raise Error, "分类 #{category.slug} 的父分类关系存在循环。" if seen[node.id]
          seen[node.id] = true
          node = categories_by_id[node.parent_id]
        end
      end

      repeated_code = skus.group_by { |sku| sku.sku_code.to_s.strip }.find { |code, records| code.empty? || records.size > 1 }
      raise Error, "SKU 代码为空或重复：#{repeated_code.first.inspect}。请先修复 SKU 数据。" if repeated_code
      irregular_code = skus.find { |sku| sku.sku_code != sku.sku_code.strip }
      raise Error, "SKU #{irregular_code.id} 的代码前后有空格，请先修复。" if irregular_code

      parent_ids = categories.filter_map(&:parent_id).to_set
      skus.each do |sku|
        unless categories_by_id.key?(sku.category_id)
          raise Error, "SKU #{sku.sku_code} 的分类不存在。"
        end
        if parent_ids.include?(sku.category_id)
          raise Error, "SKU #{sku.sku_code} 绑定了非末级分类。"
        end
      end
    end
  end
end
