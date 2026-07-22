module FamilyBrain
  module LocalePacks
    class German
      def self.data
        {
          locale: "de-DE",
          language_name: "German",
          date_order: :day_month,
          months: {
            "januar" => 1, "jan" => 1,
            "februar" => 2, "feb" => 2,
            "märz" => 3, "maerz" => 3, "mrz" => 3,
            "april" => 4, "apr" => 4,
            "mai" => 5,
            "juni" => 6, "jun" => 6,
            "juli" => 7, "jul" => 7,
            "august" => 8, "aug" => 8,
            "september" => 9, "sept" => 9, "sep" => 9,
            "oktober" => 10, "okt" => 10,
            "november" => 11, "nov" => 11,
            "dezember" => 12, "dez" => 12
          },
          weekdays: {
            "sonntag" => 0, "montag" => 1, "dienstag" => 2, "mittwoch" => 3,
            "donnerstag" => 4, "freitag" => 5, "samstag" => 6, "sonnabend" => 6
          },
          relative_days: {
            2 => %w[übermorgen uebermorgen],
            1 => %w[morgen],
            0 => %w[heute]
          },
          clock_prepositions: %w[um],
          clock_suffixes: %w[uhr],
          periods: {
            "vormittags" => :am,
            "nachmittags" => :pm,
            "abends" => :pm,
            "nachts" => :night
          },
          named_times: { "mittag" => [ 12, 0 ], "mitternacht" => [ 0, 0 ] },
          range_connectors: %w[bis],
          inclusive_words: %w[einschließlich inklusive],
          normalizations: []
        }.freeze
      end
    end
  end
end
