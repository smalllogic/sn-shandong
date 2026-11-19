class CatalogFilterQuery
  attr_reader :filters, :selected, :invalid

  def initialize(scope, category, inputs)
    @scope = scope
    @filters = category ? category.category_filters.enabled.in_display_order.includes(:catalog_filter_field).map(&:catalog_filter_field) : []
    @selected = {}
    @invalid = []
    @filters.each do |field|
      input = inputs[field.code] if inputs.respond_to?(:keys)
      parse(field, input) unless input.nil?
    end
  end

  def url_selections
    selected.transform_values do |value|
      case value
      when BigDecimal then value.to_s("F")
      when Hash then value.transform_values { |number| number.to_s("F") }
      else value
      end
    end
  end

  def results(except: nil)
    filters.reduce(@scope) do |scope, field|
      selection = selected[field.code]
      next scope if selection.nil? || field.code == except

      ids = CatalogFilterValues.new(field).matching_ids(@scope, selection)
      scope.where(id: ids)
    end
  end

  def controls
    @controls ||= filters.filter_map do |field|
      values = CatalogFilterValues.new(field)
      selection = selected[field.code]
      if field.kind == "choice"
        options = values.choices(@scope)
        next if options.empty? && selection.nil?

        if selected.except(field.code).any?
          counts = values.choices(results(except: field.code)).index_by { |option| option["code"] }
          options.each { |option| option["quantity"] = counts.dig(option["code"], "quantity") || 0 }
        end
        Array(selection).each do |code|
          options << { "code" => code, "label" => code, "quantity" => 0 } unless options.any? { |option| option["code"] == code }
        end
        [field, options]
      elsif selection || values.join(@scope).exists?
        [field, []]
      end
    end
  end

  private

  def parse(field, input)
    selection = case field.kind
    when "choice"
      unless input.is_a?(Array) && input.size <= 100 && input.all? { |value| value.is_a?(String) && value.length <= 140 }
        return @invalid << field
      end
      input.map { |value| value.strip.downcase }.reject(&:empty?).uniq.presence
    when "interval"
      return if input == ""
      decimal(input) || (return @invalid << field)
    else
      return @invalid << field unless input.respond_to?(:keys)
      bounds = %w[min max].filter_map do |bound|
        value = input[bound]
        [bound, value] unless value.nil? || (value.is_a?(String) && value.blank?)
      end.to_h
      numbers = bounds.transform_values { |value| decimal(value) }
      return if numbers.empty?
      return @invalid << field if numbers.values.any?(&:nil?)
      return @invalid << field if field.kind == "interval_cover" && numbers.size != 2
      return @invalid << field if numbers["min"] && numbers["max"] && numbers["min"] > numbers["max"]
      return @invalid << field if field.price? && numbers.values.any?(&:negative?)
      numbers
    end
    @selected[field.code] = selection unless selection.nil?
  end

  def decimal(value)
    return unless value.is_a?(String) && value.bytesize <= 26
    normalized = value.strip.tr(",", ".").tr("−", "-")
    BigDecimal(normalized) if /\A#{CatalogFilterValues::NUMBER}\z/.match?(normalized)
  end
end
