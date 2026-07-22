module FamilyBrain
  module LocalePacks
    class English
      def self.data(locale: "en-GB")
        {
          locale: locale,
          language_name: locale == "en-US" ? "American English" : "British English",
          date_order: locale == "en-US" ? :month_day : :day_month,
          months: {
            "january" => 1, "jan" => 1,
            "february" => 2, "feb" => 2,
            "march" => 3, "mar" => 3,
            "april" => 4, "apr" => 4,
            "may" => 5,
            "june" => 6, "jun" => 6,
            "july" => 7, "jul" => 7,
            "august" => 8, "aug" => 8,
            "september" => 9, "sept" => 9, "sep" => 9,
            "october" => 10, "oct" => 10,
            "november" => 11, "nov" => 11,
            "december" => 12, "dec" => 12
          },
          weekdays: {
            "sunday" => 0, "monday" => 1, "tuesday" => 2, "wednesday" => 3,
            "thursday" => 4, "friday" => 5, "saturday" => 6
          },
          relative_days: {
            2 => [ "day after tomorrow" ],
            1 => %w[tomorrow],
            0 => %w[today]
          },
          clock_prepositions: %w[at],
          clock_suffixes: [],
          periods: { "am" => :am, "a.m." => :am, "pm" => :pm, "p.m." => :pm },
          named_times: { "noon" => [ 12, 0 ], "midnight" => [ 0, 0 ] },
          range_connectors: %w[to through until],
          inclusive_words: %w[inclusive inclusively],
          normalizations: []
        }.freeze
      end
    end
  end
end
