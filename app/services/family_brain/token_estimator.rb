module FamilyBrain
  class TokenEstimator
    CHARS_PER_TOKEN = 4.0

    def self.estimate(text)
      value = text.to_s.strip
      return 0 if value.blank?

      [(value.length / CHARS_PER_TOKEN).ceil, 1].max
    end
  end
end
