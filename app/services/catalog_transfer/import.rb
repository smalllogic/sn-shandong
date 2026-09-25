require "csv"
require "digest"
require "json"
require "stringio"
require "zip"

module CatalogTransfer
  class Import
    def initialize(upload)
      @upload = upload
    end

    def call
      category_rows, sku_rows = read_archive
      validate_keys!(category_rows, sku_rows)
      ordered_categories = order_categories(category_rows)
      validate_target_keys!(category_rows, sku_rows)

      Category.transaction do
        imported_categories = {}
        ordered_categories.each do |row, line|
          slug = row.fetch("slug").strip
          parent_slug = row.fetch("parent_slug").to_s.strip
          parent = imported_categories[parent_slug] || Category.unscoped.find_by(slug: parent_slug) if parent_slug.present?
          raise Error, "categories.csv 第 #{line} 行：父分类 Slug #{parent_slug.inspect} 不存在。" if parent_slug.present? && parent.nil?

          category = Category.unscoped.find_by(slug: slug) || Category.new
          category.assign_attributes(category_attributes(row))
          category.slug = slug
          category.parent = parent
          save!(category, CATEGORY_FILE, line)
          imported_categories[slug] = category
        end

        # An existing SKU cannot remain on a category that became a parent.
        parent_ids = Category.unscoped.where.not(parent_id: nil).distinct.pluck(:parent_id)
        if Sku.where(category_id: parent_ids).exists?
          raise Error, "分类层级与现有 SKU 冲突：已有 SKU 绑定在非末级分类。"
        end

        sku_rows.each do |row, line|
          code = row.fetch("sku_code").strip
          category_slug = row.fetch("category_slug").strip
          category = imported_categories[category_slug] || Category.unscoped.find_by(slug: category_slug)
          raise Error, "skus.csv 第 #{line} 行：分类 Slug #{category_slug.inspect} 不存在。" unless category
          raise Error, "skus.csv 第 #{line} 行：分类 #{category_slug} 不是末级分类。" unless category.leaf?

          sku = Sku.find_by(sku_code: code) || Sku.new
          sku.assign_attributes(sku_attributes(row, line))
          sku.sku_code = code
          sku.category = category
          RICH_TEXT_ATTRIBUTES.each { |name| sku.public_send("#{name}=", row[name]) }
          save!(sku, SKU_FILE, line)
        end
      end

      { categories: category_rows.size, skus: sku_rows.size }
    end

    private

    def read_archive
      raise Error, "请选择 ZIP 文件。" unless @upload
      raise Error, "ZIP 文件超过 50 MB。" if @upload.size > MAX_ARCHIVE_BYTES

      @upload.rewind
      bytes = @upload.read(MAX_ARCHIVE_BYTES + 1)
      raise Error, "ZIP 文件超过 50 MB。" if bytes.bytesize > MAX_ARCHIVE_BYTES

      parsed_rows = nil
      Zip::File.open_buffer(StringIO.new(bytes)) do |zip|
        entries = catalog_entries(zip)

        category_csv = entry_text(entries.fetch(CATEGORY_FILE), CATEGORY_FILE)
        sku_csv = entry_text(entries.fetch(SKU_FILE), SKU_FILE)
        manifest = JSON.parse(entry_text(entries.fetch(MANIFEST_FILE), MANIFEST_FILE))
        unless manifest.is_a?(Hash) && manifest["sha256"].is_a?(Hash) && manifest["counts"].is_a?(Hash)
          raise Error, "ZIP 清单格式无效。"
        end
        unless manifest["format"] == FORMAT && manifest["version"] == VERSION
          raise Error, "ZIP 格式或版本不受支持。"
        end

        { CATEGORY_FILE => category_csv, SKU_FILE => sku_csv }.each do |name, csv|
          unless manifest.dig("sha256", name) == Digest::SHA256.hexdigest(csv)
            raise Error, "#{name} 校验失败，文件可能已损坏。"
          end
        end

        categories = parse_csv(category_csv, CATEGORY_FILE, CATEGORY_HEADERS)
        skus = parse_csv(sku_csv, SKU_FILE, SKU_HEADERS)
        unless manifest.dig("counts", CATEGORY_FILE) == categories.size && manifest.dig("counts", SKU_FILE) == skus.size
          raise Error, "ZIP 中的记录数量与清单不一致。"
        end
        parsed_rows = [categories, skus]
      end
      parsed_rows
    rescue Zip::Error, JSON::ParserError, CSV::MalformedCSVError => e
      raise Error, "ZIP 文件无法解析：#{e.message}"
    end

    def catalog_entries(zip)
      entries = zip.entries.reject { |entry| entry.directory? || macos_metadata?(entry.name) }
      paths = entries.map { |entry| entry.name.split("/") }
      if paths.any? { |parts| parts.any? { |part| part.blank? || part == "." || part == ".." } || parts.size > 2 }
        raise Error, "ZIP 的文件路径不符合导入格式。"
      end

      prefixes = paths.map { |parts| parts.size == 2 ? parts.first : nil }.uniq
      raise Error, "ZIP 中的数据文件必须位于同一目录。" unless prefixes.size == 1

      names = paths.map(&:last)
      if names.uniq.size != names.size
        raise Error, "ZIP 中存在重名的数据文件。"
      end
      unless names.sort == FILES.sort
        if names.include?(CATEGORY_FILE) && names.include?(SKU_FILE) && !names.include?(MANIFEST_FILE)
          raise Error, "这是旧版 ZIP，缺少 manifest.json；请在当前控制面板重新导出后上传。"
        end
        raise Error, "ZIP 文件列表不符合导入格式（实际：#{names.join('、').truncate(180)}）。需要 categories.csv、skus.csv 和 manifest.json。"
      end

      names.zip(entries).to_h
    end

    def macos_metadata?(name)
      name.split("/").any? { |part| part == "__MACOSX" || part == ".DS_Store" || part.start_with?("._") }
    end

    def entry_text(entry, name)
      raise Error, "#{name} 超过 100 MB。" if entry.size > MAX_ENTRY_BYTES
      contents = entry.get_input_stream.read(MAX_ENTRY_BYTES + 1)
      raise Error, "#{name} 超过 100 MB。" if contents.bytesize > MAX_ENTRY_BYTES
      contents
    end

    def parse_csv(bytes, filename, headers)
      text = bytes.sub(/\A\xEF\xBB\xBF/n, "").force_encoding(Encoding::UTF_8)
      raise Error, "#{filename} 不是有效的 UTF-8 文件。" unless text.valid_encoding?

      table = CSV.parse(text, headers: true)
      raise Error, "#{filename} 列名不符合当前导出格式。" unless table.headers == headers
      raise Error, "#{filename} 超过 #{MAX_ROWS} 行。" if table.size > MAX_ROWS

      table.each_with_index.map do |row, index|
        raise Error, "#{filename} 第 #{index + 2} 行列数不正确。" unless row.fields.size == headers.size
        [row.to_h, index + 2]
      end
    end

    def validate_keys!(categories, skus)
      validate_unique!(categories, "slug", CATEGORY_FILE)
      validate_unique!(skus, "sku_code", SKU_FILE)
      skus.each do |row, line|
        raise Error, "skus.csv 第 #{line} 行：分类 Slug 不能为空。" if row["category_slug"].blank?
      end
    end

    def validate_unique!(rows, key, filename)
      seen = {}
      rows.each do |row, line|
        value = row[key].to_s.strip
        raise Error, "#{filename} 第 #{line} 行：#{key} 不能为空。" if value.empty?
        raise Error, "#{filename} 第 #{line} 行：#{key} #{value.inspect} 重复。" if seen.key?(value)
        seen[value] = true
      end
    end

    def order_categories(rows)
      remaining = rows.dup
      in_file = rows.to_h { |row, _line| [row.fetch("slug").strip, true] }
      processed = {}
      ordered = []
      until remaining.empty?
        ready, remaining = remaining.partition do |row, _line|
          parent_slug = row["parent_slug"].to_s.strip
          parent_slug.empty? || !in_file.key?(parent_slug) || processed.key?(parent_slug)
        end
        raise Error, "categories.csv 的父分类关系存在循环。" if ready.empty?
        ready.each { |row, _line| processed[row.fetch("slug").strip] = true }
        ordered.concat(ready)
      end
      ordered
    end

    def validate_target_keys!(categories, skus)
      category_keys = categories.map { |row, _line| row.fetch("slug").strip }
      sku_keys = skus.map { |row, _line| row.fetch("sku_code").strip }
      duplicate_category = Category.unscoped.where(slug: category_keys).group(:slug).count.find { |_key, count| count > 1 }
      raise Error, "目标数据库的分类 Slug #{duplicate_category.first.inspect} 重复，无法安全更新。" if duplicate_category

      matching_codes = Sku.where("TRIM(sku_code) IN (?)", sku_keys).pluck(:sku_code)
      irregular_code = matching_codes.find { |code| code != code.strip }
      raise Error, "目标数据库的 SKU 代码 #{irregular_code.inspect} 前后有空格，请先修复。" if irregular_code
      duplicate_sku = matching_codes.tally.find { |_key, count| count > 1 }
      raise Error, "目标数据库的 SKU 代码 #{duplicate_sku.first.inspect} 重复，无法安全更新。" if duplicate_sku
    end

    def category_attributes(row)
      CATEGORY_ATTRIBUTES.to_h do |name|
        value = row[name]
        value = boolean(value, name) if %w[hidden featured].include?(name)
        value = integer(value, name, allow_blank: true) if %w[position featured_position].include?(name)
        [name, value]
      end
    end

    def sku_attributes(row, line)
      SKU_ATTRIBUTES.to_h do |name|
        value = row[name]
        value = integer(value, name) if name == "position"
        value = decimal(value, name) if name == "price" && value.present?
        if name == "specifications"
          value = value.present? ? JSON.parse(value) : {}
          unless value.is_a?(Array) || value.is_a?(Hash)
            raise Error, "skus.csv 第 #{line} 行：specifications 必须是 JSON 数组或对象。"
          end
        end
        [name, value]
      end
    rescue JSON::ParserError
      raise Error, "skus.csv 第 #{line} 行：specifications 不是有效 JSON。"
    end

    def boolean(value, name)
      return true if value == "true"
      return false if value == "false"
      raise Error, "#{name} 必须是 true 或 false。"
    end

    def integer(value, name, allow_blank: false)
      return nil if allow_blank && value.blank?
      Integer(value, 10)
    rescue ArgumentError, TypeError
      raise Error, "#{name} 必须是整数。"
    end

    def decimal(value, name)
      BigDecimal(value)
    rescue ArgumentError
      raise Error, "#{name} 必须是数字。"
    end

    def save!(record, filename, line)
      record.save!
    rescue ActiveRecord::RecordInvalid => e
      raise Error, "#{filename} 第 #{line} 行：#{e.record.errors.full_messages.join('、')}"
    end
  end
end
