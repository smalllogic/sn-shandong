class SkuConfigurationSelection
  def initialize(sku, option_ids)
    @sku = sku
    @option_ids = option_ids if option_ids.is_a?(Array)
  end

  def valid?
    return false unless @option_ids
    return false unless @option_ids.all? { |id| (id.is_a?(Integer) || id.is_a?(String)) && id.to_s.match?(/\A[1-9][0-9]{0,18}\z/) }

    selected_ids = @option_ids.map(&:to_s)
    groups = @sku.available_configuration_groups
    return false unless selected_ids.size == groups.size

    groups.all? { |group| group.available_options.count { |option| selected_ids.include?(option.id.to_s) } == 1 }
  end

  def line_key
    [@sku.id, @option_ids.map(&:to_s).sort.join(",").presence].compact.join(":")
  end

  def snapshot
    selected_ids = @option_ids.map(&:to_s)
    @sku.available_configuration_groups.map do |group|
      option = group.available_options.find { |item| selected_ids.include?(item.id.to_s) }
      {
        "group" => group.localized_name,
        "option" => option.localized_name,
        "model_code" => option.model_code,
        "surcharge" => option.surcharge&.to_s("F"),
        "currency" => group.currency
      }
    end
  end
end
