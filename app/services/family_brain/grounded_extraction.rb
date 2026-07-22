module FamilyBrain
  module GroundedExtraction
    MIN_CHARS = 8
    MIN_WORDS = 2

    module_function

    def meaningful_phrase?(text)
      normalized = normalize_text(text)
      return false if normalized.empty?
      return false if normalized.length < MIN_CHARS
      return false if words(text).size < MIN_WORDS
      return false if translation_artifact?(text)

      true
    end

    def evidence_present?(source_text, evidence)
      normalized_source = normalize_text(source_text)
      normalized_evidence = normalize_text(evidence)

      return false if normalized_evidence.length < MIN_CHARS

      normalized_source.include?(normalized_evidence)
    end

    def title_grounded_in_evidence?(title, evidence)
      title_tokens = significant_tokens(title)
      evidence_tokens = significant_tokens(evidence)

      return false if title_tokens.empty? || evidence_tokens.empty?

      missing_tokens = title_tokens.reject do |title_token|
        evidence_tokens.any? { |evidence_token| token_equivalent?(title_token, evidence_token) }
      end
      missing_tokens.empty? || (title_tokens.size >= 3 && missing_tokens.size == 1)
    end

    def temporal_reference?(text)
      normalized = text.to_s.downcase.tr("’ʼ`'", "").gsub(/пятгниц/u, "пятниц")
      normalized.match?(%r{(\b\d{1,2}:\d{2}\b|\b\d{1,2}[.\-/]\d{1,2}(?:[.\-/]\d{2,4})?\b|\b\d{1,2}\s+(?:січня|лютого|березня|квітня|травня|червня|липня|серпня|вересня|жовтня|листопада|грудня)\b|\bо\s*\d{1,2}\b|сьогодні|завтра|післязавтра|today|tomorrow|понеділ|вівтор|серед|четвер|пятниц|friday|saturday|sunday|monday|tuesday|wednesday|thursday|субот|неділ)}i)
    end

    def reminder_intent?(text)
      text.to_s.match?(/\b(нагад(?:ай|ати|ування|уванням)?|не забуд|remind|remember)\b/i)
    end

    def normalize_text(text)
      text.to_s.downcase.gsub(/[^\p{L}\p{N}]+/u, " ").squeeze(" ").strip
    end

    def words(text)
      normalize_text(text).scan(/\p{L}[\p{L}\p{N}]*/u)
    end

    def significant_tokens(text)
      words(text).filter { |token| token.length >= 3 }.uniq
    end

    def translation_artifact?(text)
      text.to_s.match?(/\([A-Za-z][^)]+\)/)
    end

    def token_equivalent?(left, right)
      return true if left == right

      common_length = left.chars.zip(right.chars).take_while { |left_char, right_char| left_char == right_char }.length
      common_length >= 3 && common_length >= [ left.length, right.length ].min - 2
    end
  end
end
