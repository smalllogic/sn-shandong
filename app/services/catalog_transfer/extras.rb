module CatalogTransfer
  class Extras
    FILTER_FIELDS = %w[code kind label_en label_zh label_it label_fr unit legacy_names].freeze
    NAME_FIELDS = %w[name_en name_zh name_it name_fr].freeze
    GROUP_FIELDS = (NAME_FIELDS + %w[currency position enabled]).freeze
    OPTION_FIELDS = (NAME_FIELDS + %w[model_code surcharge position enabled]).freeze
    RICH_TEXT_ATTACHMENT = "action-text-attachment"

    def initialize(assets)
      @assets = assets
    end

    def export(categories, skus)
      {
        "catalog_currency" => SiteConfig.get.catalog_currency,
        "filter_fields" => CatalogFilterField.order(:code).map { |field| field.attributes.slice(*FILTER_FIELDS) },
        "categories" => categories.to_h { |category| [category.slug, export_category(category)] },
        "skus" => skus.to_h { |sku| [sku.sku_code, export_sku(sku)] }
      }
    end

    def import(data, categories, skus, currency_conflict:)
      unless data.is_a?(Hash) && data["categories"].is_a?(Hash) && data["skus"].is_a?(Hash) &&
          data["filter_fields"].is_a?(Array) && data["catalog_currency"].is_a?(String) &&
          (data["categories"].keys - categories.keys).empty? && (data["skus"].keys - skus.keys).empty?
        raise Error, "目录扩展资料格式无效。"
      end

      config = SiteConfig.get
      if config.catalog_currency != data["catalog_currency"]
        if currency_conflict
          raise Error, "导入币种与目标目录不同。请先统一商品基础价币种。"
        end
        config.update!(catalog_currency: data["catalog_currency"])
      end
      fields = import_fields(data.fetch("filter_fields"))
      data.fetch("categories").each { |key, row| import_category(categories.fetch(key), row, fields) }
      data.fetch("skus").each { |key, row| import_sku(skus.fetch(key), row) }
    rescue KeyError, TypeError, NoMethodError, ArgumentError => error
      Rails.logger.info("Invalid catalog extras: #{error.class}")
      raise Error, "目录扩展资料存在无效字段。"
    rescue ActiveRecord::RecordInvalid => error
      raise Error, "目录扩展资料无法保存：#{error.record.errors.full_messages.to_sentence}"
    end

    private

    def attachment_reference(attachment)
      @assets.export(attachment.blob) if attachment.attached?
    end

    def export_category(category)
      {
        "image" => attachment_reference(category.image),
        "banner" => attachment_reference(category.banner),
        "filters" => category.category_filters.includes(:catalog_filter_field).map do |filter|
          filter.attributes.slice("position", "enabled").merge("code" => filter.catalog_filter_field.code)
        end
      }
    end

    def export_sku(sku)
      {
        "images" => sku.sorted_images.map do |attachment|
          @assets.export(attachment.blob).merge("position" => attachment.position)
        end,
        "groups" => sku.configuration_groups.map do |group|
          group.attributes.slice(*GROUP_FIELDS).merge(
            "key" => group.transfer_key,
            "options" => group.options.map do |option|
              option.attributes.slice(*OPTION_FIELDS).merge(
                "key" => option.transfer_key, "image" => attachment_reference(option.image)
              )
            end
          )
        end,
        "rich_text" => RICH_TEXT_ATTRIBUTES.to_h { |name| [name, export_rich_text(sku.public_send(name).body)] }
      }
    end

    def export_rich_text(body)
      return nil unless body

      references = {}
      html = body.render_attachments do |attachment|
        node = attachment.node
        blob = attachment.attachable
        if blob.is_a?(ActiveStorage::Blob)
          key = references.size.to_s
          references[key] = @assets.export(blob)
          node.remove_attribute("sgid")
          node["data-catalog-attachment"] = key
        elsif node["sgid"].present?
          raise Error, "目录富文本含有无法迁移的附件，请重新上传后导出。"
        end
        node.to_html
      end.to_html
      { "html" => html, "attachments" => references }
    end

    def import_fields(rows)
      rows.to_h do |row|
        code = row.fetch("code")
        field = CatalogFilterField.find_or_initialize_by(code: code)
        field.update!(row.slice(*FILTER_FIELDS))
        [code, field]
      end
    end

    def import_category(category, row, fields)
      category.image = @assets.import(row.fetch("image")) if row["image"]
      category.banner = @assets.import(row.fetch("banner")) if row["banner"]
      category.save!
      row.fetch("filters").each do |data|
        field = fields.fetch(data.fetch("code"))
        filter = category.category_filters.find_or_initialize_by(catalog_filter_field: field)
        filter.update!(data.slice("position", "enabled"))
      end
    end

    def import_sku(sku, row)
      images = row.fetch("images").map { |reference| [@assets.import(reference), reference["position"]] }
      sku.images = (sku.images.blobs + images.map(&:first)).uniq if images.any?
      row.fetch("rich_text").slice(*RICH_TEXT_ATTRIBUTES).each do |name, data|
        sku.public_send("#{name}=", import_rich_text(data))
      end
      sku.save!
      images.each do |blob, position|
        sku.images_attachments.where(blob_id: blob.id).update_all(position: Integer(position || 0))
      end
      row.fetch("groups").each { |data| import_group(sku, data) }
    end

    def import_group(sku, data)
      key = transfer_key(data.fetch("key"))
      group = sku.configuration_groups.find_or_initialize_by(transfer_key: key)
      group.assign_attributes(data.slice(*GROUP_FIELDS))
      data.fetch("options").each do |row|
        option_key = transfer_key(row.fetch("key"))
        option = group.options.detect { |record| record.transfer_key == option_key } || group.options.build(transfer_key: option_key)
        option.assign_attributes(row.slice(*OPTION_FIELDS))
        option.image = @assets.import(row.fetch("image")) if row["image"]
      end
      group.save!
    end

    def transfer_key(value)
      return value if value.is_a?(String) && value.match?(/\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/)

      raise Error, "SKU 配置迁移标识无效。"
    end

    def import_rich_text(data)
      return nil unless data

      fragment = Nokogiri::HTML5.fragment(data.fetch("html"))
      fragment.css("#{RICH_TEXT_ATTACHMENT}[data-catalog-attachment]").each do |node|
        reference = data.fetch("attachments").fetch(node["data-catalog-attachment"])
        blob = @assets.import(reference)
        node.remove_attribute("data-catalog-attachment")
        node["sgid"] = blob.attachable_sgid
      end
      fragment.to_html
    end
  end
end
