require "csv"

class SkuCardParametersImport
  class Error < StandardError; end

  MAX_BYTES = 1.megabyte
  MAX_ROWS = 1_000

  def initialize(upload)
    @upload = upload
  end

  def call
    unless @upload.is_a?(ActionDispatch::Http::UploadedFile)
      raise Error, "请选择一个 CSV 文件。"
    end

    text = @upload.read(MAX_BYTES + 1).force_encoding(Encoding::UTF_8)
    raise Error, "请上传 1 MB 以内的 UTF-8 CSV。" if text.bytesize > MAX_BYTES || !text.valid_encoding? || text.include?("\0")

    headers, *rows = CSV.parse(text.delete_prefix("\uFEFF"), skip_blanks: true)
    headers ||= []
    columns = headers - ["sku_code"]
    unless headers.include?("sku_code") && headers.uniq == headers &&
        columns.any? && (columns - Sku::CARD_PARAMETER_FIELDS.map(&:to_s)).empty?
      raise Error, "CSV 必须包含 sku_code，以及至少一个有效的卡片参数列。"
    end
    raise Error, "CSV 必须包含 1 至 #{MAX_ROWS} 条商品记录。" unless rows.size.between?(1, MAX_ROWS)

    seen = {}
    Sku.transaction(requires_new: true) do
      rows.each_with_index do |values, index|
        line = index + 2
        raise Error, "第 #{line} 条记录的列数与表头不一致。" unless values.size == headers.size

        row = headers.zip(values).to_h
        code = row["sku_code"].to_s.strip
        if code.empty? || seen[code]
          raise Error, "第 #{line} 条记录的 SKU 代码为空或重复。"
        end
        seen[code] = true
        matches = Sku.where(sku_code: code).limit(2).to_a
        raise Error, "第 #{line} 条记录的 SKU 代码没有唯一匹配：#{code.truncate(80)}。" unless matches.one?

        sku = matches.first
        unless sku.update(columns.index_with { |name| row[name] })
          raise Error, "第 #{line} 条记录：#{sku.errors.full_messages.join('；')}"
        end
      end
    end
    rows.size
  rescue CSV::MalformedCSVError
    raise Error, "CSV 格式有误，请检查分隔符和引号。"
  end
end
