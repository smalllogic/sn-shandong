module HomeHelper
  FAQ_ARTIFACT_PATTERNS = [
    /\AHero Badge\z/i,
    /\ATitle\z/i,
    /\ASubtitle\z/i,
    /Search Placeholder/i,
    /<\s*span\b/i,
    /\bclass\s*=/i
  ].freeze

  def clean_faq_text(text)
    text.to_s.gsub(/\r\n?/, "\n").lines.filter_map do |line|
      normalized = strip_tags(line).squish
      next if normalized.blank?
      next if faq_artifact_line?(line, normalized)

      normalized
    end.join("\n")
  end

  def clean_faq_category_name(category)
    strip_tags(category.name.to_s).squish
  end

  def faq_search_blob(faq)
    [clean_faq_text(faq.question), clean_faq_text(faq.answer)].join(" ").downcase
  end

  private

  def faq_artifact_line?(raw_line, normalized_line)
    FAQ_ARTIFACT_PATTERNS.any? do |pattern|
      raw_line.match?(pattern) || normalized_line.match?(pattern)
    end
  end
end
