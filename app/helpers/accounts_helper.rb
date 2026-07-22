module AccountsHelper
  def ai_usage_percentage(part, total)
    return "n/a" if total.to_i <= 0

    "#{((part.to_f / total) * 100).round}%"
  end

  def ai_usage_section_summary(interaction, limit: 3)
    entries = interaction.section_usage.sort_by { |_, data| -data.fetch("tokens_estimate", 0).to_i }.first(limit)
    return "no section data" if entries.empty?

    entries.map do |key, data|
      "#{key.to_s.humanize}: ~#{data.fetch('tokens_estimate', 0)}t"
    end.join(" | ")
  end
end
