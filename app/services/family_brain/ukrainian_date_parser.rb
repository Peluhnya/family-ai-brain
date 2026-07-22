module FamilyBrain
  class UkrainianDateParser < TemporalParser
    def initialize(reference_time: Time.current, timezone: nil)
      super(reference_time: reference_time, timezone: timezone, locale: "uk-UA")
    end
  end
end
