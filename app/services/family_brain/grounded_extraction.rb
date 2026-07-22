module FamilyBrain
  module GroundedExtraction
    MIN_CHARS = 8
    MIN_WORDS = 2
    REMINDER_PATTERN = %r{
      \b(?:нагад(?:ай|ати|ування|уванням)?|не\s+забуд|
      remind(?:er)?|remember\s+to|dont\s+forget|
      erinner(?:e|n|ung)?|nicht\s+vergessen)\b
    }ixu
    ACTIONABLE_PATTERN = %r{
      \b(?:треба|потрібно|необхідно|купити|оплатити|проплатити|сплатити|подзвонити|зробити|записати|замовити|відправити|підготувати|
      need\s+to|have\s+to|must|buy|pay|call|book|order|send|prepare|
      muss|müssen|soll|brauche|kaufen|bezahlen|zahlen|anrufen|machen|buchen|bestellen|schicken|vorbereiten)\b
    }ixu
    ONLY_REMINDER_PATTERN = %r{
      (?:\b(?:лише|тільки)\s+(?:створити\s+)?нагадування\b|
      \bonly\s+(?:create\s+|set\s+)?(?:a\s+)?reminder\b|
      \bnur\s+(?:eine\s+)?erinnerung\b)
    }ixu
    ONLY_TASK_PATTERN = %r{
      (?:\b(?:лише|тільки)\s+(?:створити\s+)?задач|\bonly\s+(?:create\s+)?(?:a\s+)?(?:task|todo)\b|
      \bnur\s+(?:eine\s+)?aufgabe\b)
    }ixu
    NO_REMINDER_PATTERN = %r{
      (?:\bбез\s+нагадування\b|\bне\s+нагадуй\b|\bнагадування\s+не\s+потрібне\b|
      \bwithout\s+(?:a\s+)?reminder\b|\bdont\s+remind\b|
      \bohne\s+erinnerung\b|\berinnere\s+mich\s+nicht\b|\bkeine\s+erinnerung\b)
    }ixu
    FUTURE_PATTERN = %r{
      \b(?:завтра|післязавтра|буде|будемо|піде|поїде|поїдемо|планує|збираєть|має\s+відпустку|
      tomorrow|day\s+after\s+tomorrow|will|going\s+to|plan(?:s|ning)?|vacation\s+starts?|
      morgen|übermorgen|uebermorgen|wird|werden|plan(?:e|t|en)|vorhab(?:e|en)|urlaub\s+(?:beginnt|startet))\b
    }ixu
    DURABLE_TEMPORAL_PATTERN = %r{
      \b(?:завжди|зазвичай|щороку|кожн(?:ого|ої|і|у)|народив|народила|день\s+народження|
      always|usually|every|annually|born|birthday|
      immer|normalerweise|jed(?:e|er|es|en)|jährlich|jaehrlich|geboren|geburtstag)\b
    }ixu
    module_function

    def meaningful_phrase?(text)
      normalized = normalize_text(text)
      return false if normalized.empty?
      return false if normalized.length < MIN_CHARS
      return false if words(text).size < MIN_WORDS
      return false if translation_artifact?(text)

      true
    end

    def meaningful_title?(text)
      normalized = normalize_text(text)
      return false if normalized.length < 3
      return false if words(text).empty?
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

    def grounded_title(title, evidence)
      stripped_title = title.to_s.strip
      return stripped_title if meaningful_title?(stripped_title) && title_grounded_in_evidence?(stripped_title, evidence)

      title_tokens = significant_tokens(stripped_title)
      matching_evidence_words = evidence.to_s.scan(/\p{L}[\p{L}\p{N}]*/u).select do |evidence_word|
        title_tokens.any? { |title_token| token_equivalent?(title_token, evidence_word.downcase) }
      end.uniq { |word| word.downcase }
      candidate = matching_evidence_words.join(" ").strip
      return unless meaningful_title?(candidate)
      return unless title_grounded_in_evidence?(candidate, evidence)

      candidate.sub(/\A\p{Ll}/u) { |character| character.upcase }
    end

    def temporal_reference?(text, locale: nil, reference_time: Time.current, timezone: nil)
      FamilyBrain::TemporalParser.new(reference_time: reference_time, timezone: timezone, locale: locale)
        .temporal_reference?(text)
    end

    def reminder_intent?(text)
      normalized_for_intent(text).match?(REMINDER_PATTERN)
    end

    def actionable?(text)
      normalized_for_intent(text).match?(ACTIONABLE_PATTERN)
    end

    def only_reminder?(text)
      normalized_for_intent(text).match?(ONLY_REMINDER_PATTERN)
    end

    def only_task?(text)
      normalized_for_intent(text).match?(ONLY_TASK_PATTERN)
    end

    def no_reminder?(text)
      normalized_for_intent(text).match?(NO_REMINDER_PATTERN)
    end

    def future_intent?(text)
      normalized_for_intent(text).match?(FUTURE_PATTERN)
    end

    def durable_temporal_fact?(text)
      normalized_for_intent(text).match?(DURABLE_TEMPORAL_PATTERN)
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

    def normalized_for_intent(text)
      text.to_s.downcase.tr("’ʼ`'", "").gsub(/пятгниц/u, "пятниц")
    end
    private_class_method :normalized_for_intent

    def token_equivalent?(left, right)
      return true if left == right

      common_length = left.chars.zip(right.chars).take_while { |left_char, right_char| left_char == right_char }.length
      common_length >= 3 && common_length >= [ left.length, right.length ].min - 2
    end
  end
end
