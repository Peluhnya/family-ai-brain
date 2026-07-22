module FamilyBrain
  module LanguageResolver
    UKRAINIAN_PATTERN = /[іїєґа-я]/iu
    GERMAN_STRONG_PATTERN = /[äöüß]/iu
    GERMAN_WORDS = %w[ich wir der die das heute morgen übermorgen erinnerung erinnere bezahlen urlaub kaufen bis uhr].freeze
    ENGLISH_WORDS = %w[i we the today tomorrow reminder remind pay vacation buy until through at].freeze

    module_function

    def resolve(text:, fallback: nil, context: nil)
      normalized_fallback = FamilyBrain::LocaleCatalog.normalize(fallback)
      detect(text, fallback: normalized_fallback) ||
        detect(Array(context).join("\n"), fallback: normalized_fallback) ||
        normalized_fallback ||
        FamilyBrain::LocaleCatalog::DEFAULT_LOCALE
    end

    def for_message(family:, message:, context: nil)
      context ||= family.ai_interactions
        .where(role: "user")
        .where("id < ?", message.id)
        .order(id: :desc)
        .limit(6)
        .pluck(:content)

      resolve(text: message.content, context: context, fallback: family.locale)
    end

    def language_name(text:, fallback: nil, context: nil)
      FamilyBrain::LocaleCatalog.language_name(resolve(text: text, context: context, fallback: fallback))
    end

    def detect(text, fallback: nil)
      value = text.to_s.downcase
      return if value.blank?

      return "uk-UA" if value.match?(UKRAINIAN_PATTERN)
      return "de-DE" if value.match?(GERMAN_STRONG_PATTERN)

      german_score = word_score(value, GERMAN_WORDS)
      english_score = word_score(value, ENGLISH_WORDS)
      return "de-DE" if german_score > english_score

      english_fallback(fallback) if english_score > german_score
    end
    private_class_method :detect

    def word_score(text, words)
      words.count { |word| text.match?(/(?<!\p{L})#{Regexp.escape(word)}(?!\p{L})/iu) }
    end
    private_class_method :word_score

    def english_fallback(fallback)
      %w[en-GB en-US].include?(fallback) ? fallback : "en-GB"
    end
    private_class_method :english_fallback
  end
end
