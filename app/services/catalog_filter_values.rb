class CatalogFilterValues
  NUMBER = '[+-]?(?:[0-9]{1,14}(?:[.][0-9]{1,8})?|[.][0-9]{1,8})'
  EMPTY_ARRAY = "'[]'::jsonb"
  EMPTY_OBJECT = "'{}'::jsonb"

  # Support the catalogue's translated array and the older name/value object.
  # The primary value is preferred, so changing language cannot change matches.
  LEGACY_VALUES = <<~SQL.freeze
    SELECT item->>'key' AS name,
           item->>'key_zh' AS name_zh, item->>'key_it' AS name_it, item->>'key_fr' AS name_fr,
           COALESCE(NULLIF(btrim(item->>'value'), ''), NULLIF(btrim(item->>'value_zh'), ''),
                    NULLIF(btrim(item->>'value_it'), ''), NULLIF(btrim(item->>'value_fr'), '')) AS raw
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(skus.specifications) = 'array'
                                  THEN skus.specifications ELSE #{EMPTY_ARRAY} END) AS item
    UNION ALL
    SELECT key, NULL, NULL, NULL, NULLIF(btrim(value), '')
    FROM jsonb_each_text(CASE WHEN jsonb_typeof(skus.specifications) = 'object'
                              THEN skus.specifications ELSE #{EMPTY_OBJECT} END)
  SQL

  def initialize(field)
    @field = field
    @connection = Sku.connection
  end

  def join(scope)
    scope.joins("INNER JOIN LATERAL (#{value_sql}) AS filter_value ON TRUE")
  end

  def matching_ids(scope, selection)
    values = join(scope)
    case @field.kind
    when "choice"
      values = values.where("filter_value.value IN (?)", selection)
    when "interval"
      values = values.where("filter_value.value <= ? AND filter_value.upper_value >= ?", selection, selection)
    when "interval_cover"
      values = values.where("filter_value.value <= ? AND filter_value.upper_value >= ?", selection["min"], selection["max"])
    else
      values = values.where("filter_value.value >= ?", selection["min"]) if selection["min"]
      values = values.where("filter_value.value <= ?", selection["max"]) if selection["max"]
    end
    values.reorder(nil).select(:id)
  end

  def count(scope)
    join(scope).count
  end

  def choices(scope)
    counted = join(scope).reorder(nil).group("filter_value.value").select(
      "filter_value.value AS code, MIN(filter_value.label) AS label, COUNT(*) AS quantity"
    )
    @connection.select_all(counted.order(Arel.sql("MIN(filter_value.label)")).to_sql).to_a
  end

  private

  def value_sql
    return "SELECT skus.price AS value WHERE skus.price >= 0" if @field.price?

    # All configuration values are quoted, never interpolated as SQL syntax.
    aliases = @field.source_names.map { |name| @connection.quote(name) }.join(", ")
    names_match = %w[name name_zh name_it name_fr].map { |name| "lower(btrim(legacy.#{name})) IN (#{aliases})" }.join(" OR ")
    raw = "replace(replace(legacy.raw, '℃', '°C'), '−', '-')"
    if @field.kind == "choice"
      parsed = "SELECT lower(legacy.raw) AS value, legacy.raw AS label FROM (#{LEGACY_VALUES}) legacy WHERE (#{names_match}) AND char_length(legacy.raw) <= 140"
      return <<~SQL
        SELECT MIN(value) AS value, MIN(label) AS label FROM (#{parsed}) parsed
        HAVING COUNT(DISTINCT value) = 1
      SQL
    end

    unit = @field.unit.presence
    suffix = unit ? "(?:[[:space:]]*#{Regexp.escape(unit.gsub('℃', '°C'))})?" : ""
    interval = @field.interval?
    separator = '[[:space:]]*(?:-|–|—|~|～|to)[[:space:]]*'
    pattern = interval ? "^(#{NUMBER})#{suffix}#{separator}(#{NUMBER})#{suffix}$" : "^(#{NUMBER})#{suffix}$"
    upper = interval ? "matches.parts[2]::numeric" : "NULL::numeric"
    <<~SQL
      SELECT MIN(value) AS value, MIN(upper_value) AS upper_value
      FROM (
        SELECT matches.parts[1]::numeric AS value, #{upper} AS upper_value
        FROM (#{LEGACY_VALUES}) legacy
        CROSS JOIN LATERAL (SELECT regexp_match(#{raw}, #{@connection.quote(pattern)}, 'i') AS parts) matches
        WHERE (#{names_match}) AND matches.parts IS NOT NULL
      ) parsed
      WHERE upper_value IS NULL OR value <= upper_value
      HAVING COUNT(DISTINCT (value, upper_value)) = 1
    SQL
  end
end
