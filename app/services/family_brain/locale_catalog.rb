module FamilyBrain
  module LocaleCatalog
    SUPPORTED_LOCALES = %w[uk-UA de-DE en-GB en-US].freeze
    DEFAULT_LOCALE = "uk-UA"
    ALIASES = {
      "uk" => "uk-UA",
      "uk-ua" => "uk-UA",
      "ua" => "uk-UA",
      "de" => "de-DE",
      "de-de" => "de-DE",
      "en" => "en-GB",
      "en-gb" => "en-GB",
      "en-us" => "en-US"
    }.freeze
    RESULT_COPY = {
      "uk-UA" => {
        created: "Створено", updated: "Оновлено", existing: "Вже існує", failed: "Не вдалося зберегти"
      },
      "de-DE" => {
        created: "Erstellt", updated: "Aktualisiert", existing: "Bereits vorhanden", failed: "Speichern fehlgeschlagen"
      },
      "en-GB" => {
        created: "Created", updated: "Updated", existing: "Already exists", failed: "Could not save"
      },
      "en-US" => {
        created: "Created", updated: "Updated", existing: "Already exists", failed: "Could not save"
      }
    }.freeze
    ACTION_COPY = {
      "uk-UA" => {
        task_exists: "Відповідна активна задача вже існує.", task_created: "Задачу створено.",
        task_unchanged: "У задачі немає нових даних для оновлення.", task_updated: "Задачу оновлено.",
        reminder_exists: "Відповідне активне нагадування вже існує.", reminder_created: "Нагадування створено.",
        reminder_unchanged: "У нагадуванні немає нових даних для оновлення.", reminder_updated: "Нагадування оновлено.",
        event_exists: "Відповідна подія вже існує.", event_created: "Подію створено.",
        event_unchanged: "У події немає нових даних для оновлення.", event_updated: "Подію оновлено.",
        already_processed: "Цю дію вже було оброблено."
      },
      "de-DE" => {
        task_exists: "Eine passende aktive Aufgabe existiert bereits.", task_created: "Aufgabe erstellt.",
        task_unchanged: "Für die Aufgabe liegen keine neuen Änderungen vor.", task_updated: "Aufgabe aktualisiert.",
        reminder_exists: "Eine passende aktive Erinnerung existiert bereits.", reminder_created: "Erinnerung erstellt.",
        reminder_unchanged: "Für die Erinnerung liegen keine neuen Änderungen vor.", reminder_updated: "Erinnerung aktualisiert.",
        event_exists: "Ein passender Termin existiert bereits.", event_created: "Termin erstellt.",
        event_unchanged: "Für den Termin liegen keine neuen Änderungen vor.", event_updated: "Termin aktualisiert.",
        already_processed: "Diese Aktion wurde bereits verarbeitet."
      },
      "en-GB" => {
        task_exists: "A matching active task already exists.", task_created: "Task created.",
        task_unchanged: "The task has no new changes.", task_updated: "Task updated.",
        reminder_exists: "A matching active reminder already exists.", reminder_created: "Reminder created.",
        reminder_unchanged: "The reminder has no new changes.", reminder_updated: "Reminder updated.",
        event_exists: "A matching event already exists.", event_created: "Event created.",
        event_unchanged: "The event has no new changes.", event_updated: "Event updated.",
        already_processed: "This action has already been processed."
      }
    }.tap { |copy| copy["en-US"] = copy.fetch("en-GB") }.freeze
    UI_COPY = {
      "uk-UA" => {
        analysing: "Аналізую запит…", updating: "Оновлюю сімейний простір…", responding: "Формую відповідь…",
        unable_to_respond: "Вибач, я не зміг сформувати відповідь.", request_failed: "Вибач, не вдалося обробити запит.",
        provider_unconfigured: "AI-провайдер для цього акаунта не налаштований. Додай його в налаштуваннях акаунта."
      },
      "de-DE" => {
        analysing: "Anfrage wird analysiert…", updating: "Familienbereich wird aktualisiert…", responding: "Antwort wird erstellt…",
        unable_to_respond: "Entschuldigung, ich konnte keine Antwort erstellen.", request_failed: "Entschuldigung, die Anfrage konnte nicht verarbeitet werden.",
        provider_unconfigured: "Für dieses Konto ist kein KI-Anbieter konfiguriert. Füge ihn in den Kontoeinstellungen hinzu."
      },
      "en-GB" => {
        analysing: "Analysing the request…", updating: "Updating the family space…", responding: "Preparing the response…",
        unable_to_respond: "Sorry, I could not prepare a response.", request_failed: "Sorry, the request could not be processed.",
        provider_unconfigured: "No AI provider is configured for this account. Add one in the account settings."
      }
    }.tap { |copy| copy["en-US"] = copy.fetch("en-GB") }.freeze
    ERROR_COPY = {
      "uk-UA" => {
        reminder_time_missing: "Не вдалося визначити час нагадування.", event_start_missing: "Не вдалося визначити початок події.",
        event_end_invalid: "Кінець події має бути після початку.", title_blank: "Назва дії порожня.",
        title_unverified: "Назва дії не підтверджена повідомленням користувача.", evidence_missing: "Дія не має підтвердження в повідомленні користувача.",
        evidence_unverified: "Підтвердження дії відсутнє в повідомленнях користувача."
      },
      "de-DE" => {
        reminder_time_missing: "Die Erinnerungszeit konnte nicht bestimmt werden.", event_start_missing: "Der Beginn des Termins konnte nicht bestimmt werden.",
        event_end_invalid: "Das Ende des Termins muss nach dem Beginn liegen.", title_blank: "Der Aktionstitel ist leer.",
        title_unverified: "Der Aktionstitel wird durch die Benutzernachricht nicht bestätigt.", evidence_missing: "Für die Aktion fehlt ein Beleg aus der Benutzernachricht.",
        evidence_unverified: "Der Beleg ist in den Benutzernachrichten nicht vorhanden."
      },
      "en-GB" => {
        reminder_time_missing: "The reminder time could not be determined.", event_start_missing: "The event start could not be determined.",
        event_end_invalid: "The event must end after it starts.", title_blank: "The action title is empty.",
        title_unverified: "The action title is not supported by the user message.", evidence_missing: "The action has no evidence from a user message.",
        evidence_unverified: "The evidence is not present in the user messages."
      }
    }.tap { |copy| copy["en-US"] = copy.fetch("en-GB") }.freeze

    module_function

    def normalize(locale)
      value = locale.to_s.strip
      return if value.blank?

      ALIASES[value.downcase]
    end

    def pack(locale)
      case normalize(locale) || DEFAULT_LOCALE
      when "de-DE" then FamilyBrain::LocalePacks::German.data
      when "en-US" then FamilyBrain::LocalePacks::English.data(locale: "en-US")
      when "en-GB" then FamilyBrain::LocalePacks::English.data(locale: "en-GB")
      else FamilyBrain::LocalePacks::Ukrainian.data
      end
    end

    def language_name(locale)
      pack(locale).fetch(:language_name)
    end

    def copy(locale, key)
      RESULT_COPY.fetch(normalize(locale) || DEFAULT_LOCALE).fetch(key)
    end

    def action_copy(locale, key)
      ACTION_COPY.fetch(normalize(locale) || DEFAULT_LOCALE).fetch(key)
    end

    def ui_copy(locale, key)
      UI_COPY.fetch(normalize(locale) || DEFAULT_LOCALE).fetch(key)
    end

    def error_copy(locale, key)
      ERROR_COPY.fetch(normalize(locale) || DEFAULT_LOCALE).fetch(key)
    end

    def unique_language_packs(preferred_locale)
      preferred = pack(preferred_locale)
      others = [
        FamilyBrain::LocalePacks::Ukrainian.data,
        FamilyBrain::LocalePacks::German.data,
        FamilyBrain::LocalePacks::English.data(locale: english_locale(preferred_locale))
      ]

      [ preferred, *others ].uniq { |candidate| candidate[:locale].split("-").first }
    end

    def english_locale(locale)
      normalize(locale) == "en-US" ? "en-US" : "en-GB"
    end
  end
end
