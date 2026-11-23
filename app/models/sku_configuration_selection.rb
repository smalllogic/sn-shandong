class SkuConfigurationSelection
  def initialize(sku, option_ids)
    @sku = sku
    @option_ids = option_ids if option_ids.is_a?(Array)
  end

  def valid?
    return false unless @option_ids
    return false unless @option_ids.all? { |id| (id.is_a?(Integer) || id.is_a?(String)) && id.to_s.match?(/\A[1-9][0-9]{0,18}\z/) }

    choices = selected_options
    choices.size == @option_ids.size && choices.map(&:first).uniq.size == choices.size
  end

  def line_key
    [@sku.id, @option_ids.map(&:to_s).sort.join(",").presence].compact.join(":")
  end

  def snapshot
    selected_options.map do |group, option|
      {
        "group" => group.localized_name,
        "option" => option.localized_name,
        "model_code" => option.model_code,
        "surcharge" => option.surcharge&.to_s("F"),
        "currency" => group.currency
      }
    end
  end

  private

  def selected_options
    return [] if @option_ids.empty?

    @selected_options ||= begin
      selected_ids = @option_ids.map(&:to_s)
      @sku.available_configuration_groups.flat_map do |group|
        group.available_options.filter_map do |option|
          [group, option] if selected_ids.include?(option.id.to_s)
        end
      end
    end
  end
end
