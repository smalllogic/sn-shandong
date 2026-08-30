module HomeHelper
  FAQ_ARTIFACT_PATTERNS = [
    /\AHero Badge\z/i,
    /\ATitle\z/i,
    /\ASubtitle\z/i,
    /Search Placeholder/i,
    /<\s*span\b/i,
    /\bclass\s*=/i
  ].freeze

  FLAG_SVGS = {
    "CN" => <<~SVG.freeze,
      <svg viewBox="0 0 64 48" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true">
        <rect width="64" height="48" rx="6" fill="#EE1C25"/>
        <path fill="#FFDE00" d="m14.6 8.1 1.7 5.2h5.5l-4.5 3.2 1.7 5.2-4.4-3.2-4.5 3.2 1.7-5.2-4.5-3.2h5.5z"/>
        <path fill="#FFDE00" d="m27 7.3 1 2.9h3.1l-2.5 1.9 1 2.9-2.6-1.9-2.5 1.9 1-2.9-2.5-1.9H26z"/>
        <path fill="#FFDE00" d="m31.6 14.1 1 2.9h3.1l-2.5 1.9 1 2.9-2.6-1.9-2.5 1.9 1-2.9-2.5-1.9h3.1z"/>
        <path fill="#FFDE00" d="m31 24.2 1 2.9h3.1L32.6 29l1 2.9-2.6-1.9-2.5 1.9 1-2.9-2.5-1.9h3.1z"/>
        <path fill="#FFDE00" d="m26 31 1 2.9h3.1l-2.5 1.9 1 2.9-2.6-1.9-2.5 1.9 1-2.9-2.5-1.9H25z"/>
      </svg>
    SVG
    "FR" => <<~SVG.freeze,
      <svg viewBox="0 0 64 48" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true">
        <rect width="21.33" height="48" rx="6" fill="#0055A4"/>
        <rect x="21.33" width="21.34" height="48" fill="#FFFFFF"/>
        <rect x="42.67" width="21.33" height="48" rx="6" fill="#EF4135"/>
      </svg>
    SVG
    "DE" => <<~SVG.freeze,
      <svg viewBox="0 0 64 48" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true">
        <rect width="64" height="16" rx="6" fill="#000000"/>
        <rect y="16" width="64" height="16" fill="#DD0000"/>
        <rect y="32" width="64" height="16" rx="6" fill="#FFCE00"/>
      </svg>
    SVG
    "CZ" => <<~SVG.freeze,
      <svg viewBox="0 0 64 48" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true">
        <rect width="64" height="24" rx="6" fill="#FFFFFF"/>
        <rect y="24" width="64" height="24" rx="6" fill="#D7141A"/>
        <path d="M0 0v48l30-24Z" fill="#11457E"/>
      </svg>
    SVG
    "ES" => <<~SVG.freeze,
      <svg viewBox="0 0 64 48" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true">
        <rect width="64" height="48" rx="6" fill="#AA151B"/>
        <rect y="12" width="64" height="24" fill="#F1BF00"/>
      </svg>
    SVG
    "GB" => <<~SVG.freeze,
      <svg viewBox="0 0 64 48" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true">
        <rect width="64" height="48" rx="6" fill="#012169"/>
        <path d="M0 0 64 48M64 0 0 48" stroke="#FFFFFF" stroke-width="10"/>
        <path d="M0 0 64 48M64 0 0 48" stroke="#C8102E" stroke-width="6"/>
        <path d="M32 0v48M0 24h64" stroke="#FFFFFF" stroke-width="16"/>
        <path d="M32 0v48M0 24h64" stroke="#C8102E" stroke-width="10"/>
      </svg>
    SVG
    "AU" => <<~SVG.freeze,
      <svg viewBox="0 0 64 48" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true">
        <rect width="64" height="48" rx="6" fill="#012169"/>
        <rect width="32" height="24" fill="#012169"/>
        <path d="M0 0 32 24M32 0 0 24" stroke="#FFFFFF" stroke-width="5"/>
        <path d="M0 0 32 24M32 0 0 24" stroke="#C8102E" stroke-width="3"/>
        <path d="M16 0v24M0 12h32" stroke="#FFFFFF" stroke-width="8"/>
        <path d="M16 0v24M0 12h32" stroke="#C8102E" stroke-width="5"/>
        <circle cx="47" cy="14" r="3" fill="#FFFFFF"/>
        <circle cx="53" cy="24" r="2.5" fill="#FFFFFF"/>
        <circle cx="44" cy="30" r="2.5" fill="#FFFFFF"/>
        <circle cx="57" cy="35" r="2.5" fill="#FFFFFF"/>
        <circle cx="49" cy="39" r="3" fill="#FFFFFF"/>
      </svg>
    SVG
    "AE" => <<~SVG.freeze,
      <svg viewBox="0 0 64 48" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true">
        <rect width="16" height="48" rx="6" fill="#FF0000"/>
        <rect x="16" width="48" height="16" rx="6" fill="#00732F"/>
        <rect x="16" y="16" width="48" height="16" fill="#FFFFFF"/>
        <rect x="16" y="32" width="48" height="16" rx="6" fill="#000000"/>
      </svg>
    SVG
    "US" => <<~SVG.freeze,
      <svg viewBox="0 0 64 48" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true">
        <rect width="64" height="48" rx="6" fill="#FFFFFF"/>
        <g fill="#B22234">
          <rect width="64" height="3.69"/>
          <rect y="7.38" width="64" height="3.69"/>
          <rect y="14.76" width="64" height="3.69"/>
          <rect y="22.14" width="64" height="3.69"/>
          <rect y="29.52" width="64" height="3.69"/>
          <rect y="36.9" width="64" height="3.69"/>
          <rect y="44.28" width="64" height="3.72"/>
        </g>
        <rect width="28" height="25.85" rx="6" fill="#3C3B6E"/>
        <g fill="#FFFFFF">
          <circle cx="5" cy="5" r="1.1"/><circle cx="10" cy="5" r="1.1"/><circle cx="15" cy="5" r="1.1"/><circle cx="20" cy="5" r="1.1"/><circle cx="25" cy="5" r="1.1"/>
          <circle cx="7.5" cy="9" r="1.1"/><circle cx="12.5" cy="9" r="1.1"/><circle cx="17.5" cy="9" r="1.1"/><circle cx="22.5" cy="9" r="1.1"/>
          <circle cx="5" cy="13" r="1.1"/><circle cx="10" cy="13" r="1.1"/><circle cx="15" cy="13" r="1.1"/><circle cx="20" cy="13" r="1.1"/><circle cx="25" cy="13" r="1.1"/>
          <circle cx="7.5" cy="17" r="1.1"/><circle cx="12.5" cy="17" r="1.1"/><circle cx="17.5" cy="17" r="1.1"/><circle cx="22.5" cy="17" r="1.1"/>
          <circle cx="5" cy="21" r="1.1"/><circle cx="10" cy="21" r="1.1"/><circle cx="15" cy="21" r="1.1"/><circle cx="20" cy="21" r="1.1"/><circle cx="25" cy="21" r="1.1"/>
        </g>
      </svg>
    SVG
  }.freeze

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

  def flag_svg(code, classes: "")
    svg = FLAG_SVGS[code.to_s.upcase]
    return code.to_s.upcase if svg.blank?

    svg.sub("<svg ", %(<svg class="#{ERB::Util.html_escape(classes)}" )).html_safe
  end

  private

  def faq_artifact_line?(raw_line, normalized_line)
    FAQ_ARTIFACT_PATTERNS.any? do |pattern|
      raw_line.match?(pattern) || normalized_line.match?(pattern)
    end
  end
end
