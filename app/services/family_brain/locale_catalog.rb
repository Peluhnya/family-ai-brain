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
        knowledge_exists: "Таке знання вже існує.", knowledge_created: "Знання збережено.",
        knowledge_unchanged: "У знанні немає нових даних.", knowledge_updated: "Знання оновлено.",
        life_log_exists: "Такий запис історії вже існує.", life_log_created: "Запис додано до історії.",
        life_log_unchanged: "У записі історії немає нових даних.", life_log_updated: "Запис історії оновлено.",
        document_exists: "Такий документ уже існує.", document_created: "Документ створено.",
        document_unchanged: "У документі немає нових даних.", document_updated: "Документ оновлено.",
        automation_exists: "Таке правило автоматизації вже існує.", automation_created: "Автоматизацію створено.",
        automation_unchanged: "В автоматизації немає нових даних.", automation_updated: "Автоматизацію оновлено.",
        already_processed: "Цю дію вже було оброблено."
      },
      "de-DE" => {
        task_exists: "Eine passende aktive Aufgabe existiert bereits.", task_created: "Aufgabe erstellt.",
        task_unchanged: "Für die Aufgabe liegen keine neuen Änderungen vor.", task_updated: "Aufgabe aktualisiert.",
        reminder_exists: "Eine passende aktive Erinnerung existiert bereits.", reminder_created: "Erinnerung erstellt.",
        reminder_unchanged: "Für die Erinnerung liegen keine neuen Änderungen vor.", reminder_updated: "Erinnerung aktualisiert.",
        event_exists: "Ein passender Termin existiert bereits.", event_created: "Termin erstellt.",
        event_unchanged: "Für den Termin liegen keine neuen Änderungen vor.", event_updated: "Termin aktualisiert.",
        knowledge_exists: "Dieses Wissen ist bereits gespeichert.", knowledge_created: "Wissen gespeichert.",
        knowledge_unchanged: "Keine neuen Wissensänderungen.", knowledge_updated: "Wissen aktualisiert.",
        life_log_exists: "Dieser Verlaufseintrag existiert bereits.", life_log_created: "Zum Verlauf hinzugefügt.",
        life_log_unchanged: "Keine neuen Verlaufsänderungen.", life_log_updated: "Verlauf aktualisiert.",
        document_exists: "Dieses Dokument existiert bereits.", document_created: "Dokument erstellt.",
        document_unchanged: "Das Dokument enthält keine neuen Änderungen.", document_updated: "Dokument aktualisiert.",
        automation_exists: "Diese Automatisierung existiert bereits.", automation_created: "Automatisierung erstellt.",
        automation_unchanged: "Die Automatisierung enthält keine neuen Änderungen.", automation_updated: "Automatisierung aktualisiert.",
        already_processed: "Diese Aktion wurde bereits verarbeitet."
      },
      "en-GB" => {
        task_exists: "A matching active task already exists.", task_created: "Task created.",
        task_unchanged: "The task has no new changes.", task_updated: "Task updated.",
        reminder_exists: "A matching active reminder already exists.", reminder_created: "Reminder created.",
        reminder_unchanged: "The reminder has no new changes.", reminder_updated: "Reminder updated.",
        event_exists: "A matching event already exists.", event_created: "Event created.",
        event_unchanged: "The event has no new changes.", event_updated: "Event updated.",
        knowledge_exists: "This knowledge is already stored.", knowledge_created: "Knowledge saved.",
        knowledge_unchanged: "The knowledge has no new changes.", knowledge_updated: "Knowledge updated.",
        life_log_exists: "This history entry already exists.", life_log_created: "Added to history.",
        life_log_unchanged: "The history entry has no new changes.", life_log_updated: "History updated.",
        document_exists: "This document already exists.", document_created: "Document created.",
        document_unchanged: "The document has no new changes.", document_updated: "Document updated.",
        automation_exists: "This automation already exists.", automation_created: "Automation created.",
        automation_unchanged: "The automation has no new changes.", automation_updated: "Automation updated.",
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
        evidence_unverified: "Підтвердження дії відсутнє в повідомленнях користувача.",
        knowledge_conflict: "Нове значення суперечить наявному знанню й потребує підтвердженого оновлення.",
        knowledge_key_invalid: "Ключ знання має бути у форматі snake_case.",
        memory_value_unverified: "Значення пам’яті не підтверджене точною цитатою користувача.",
        life_log_time_missing: "Не вдалося визначити час події для історії.",
        life_log_time_future: "Майбутню подію не можна записати як завершену історію.",
        document_content_unverified: "Вміст документа не підтверджено точною цитатою з розмови.",
        automation_trigger_invalid: "Непідтримуваний тригер автоматизації.",
        automation_action_invalid: "Непідтримувана дія автоматизації.",
        automation_keyword_missing: "Не вказане ключове слово автоматизації.",
        automation_keyword_unverified: "Ключове слово не підтверджене повідомленням користувача.",
        automation_time_invalid: "Час автоматизації має бути у форматі HH:MM.",
        automation_weekday_invalid: "Некоректний день тижня автоматизації."
      },
      "de-DE" => {
        reminder_time_missing: "Die Erinnerungszeit konnte nicht bestimmt werden.", event_start_missing: "Der Beginn des Termins konnte nicht bestimmt werden.",
        event_end_invalid: "Das Ende des Termins muss nach dem Beginn liegen.", title_blank: "Der Aktionstitel ist leer.",
        title_unverified: "Der Aktionstitel wird durch die Benutzernachricht nicht bestätigt.", evidence_missing: "Für die Aktion fehlt ein Beleg aus der Benutzernachricht.",
        evidence_unverified: "Der Beleg ist in den Benutzernachrichten nicht vorhanden.",
        knowledge_conflict: "Der neue Wert widerspricht gespeichertem Wissen und benötigt eine bestätigte Aktualisierung.",
        knowledge_key_invalid: "Der Wissensschlüssel muss snake_case verwenden.",
        memory_value_unverified: "Der Speicherwert ist nicht durch ein exaktes Benutzerzitat belegt.",
        life_log_time_missing: "Der Zeitpunkt des Verlaufseintrags konnte nicht bestimmt werden.",
        life_log_time_future: "Ein zukünftiges Ereignis kann nicht als abgeschlossene Geschichte gespeichert werden.",
        document_content_unverified: "Der Dokumentinhalt ist nicht durch ein exaktes Zitat aus dem Gespräch belegt.",
        automation_trigger_invalid: "Nicht unterstützter Automatisierungsauslöser.",
        automation_action_invalid: "Nicht unterstützte Automatisierungsaktion.",
        automation_keyword_missing: "Das Schlüsselwort der Automatisierung fehlt.",
        automation_keyword_unverified: "Das Schlüsselwort ist nicht durch die Benutzernachricht belegt.",
        automation_time_invalid: "Die Automatisierungszeit muss HH:MM verwenden.",
        automation_weekday_invalid: "Ungültiger Wochentag für die Automatisierung."
      },
      "en-GB" => {
        reminder_time_missing: "The reminder time could not be determined.", event_start_missing: "The event start could not be determined.",
        event_end_invalid: "The event must end after it starts.", title_blank: "The action title is empty.",
        title_unverified: "The action title is not supported by the user message.", evidence_missing: "The action has no evidence from a user message.",
        evidence_unverified: "The evidence is not present in the user messages.",
        knowledge_conflict: "The new value conflicts with stored knowledge and needs a confirmed update.",
        knowledge_key_invalid: "The knowledge key must use snake_case.",
        memory_value_unverified: "The memory value is not supported by an exact user quote.",
        life_log_time_missing: "The history time could not be determined.",
        life_log_time_future: "A future event cannot be stored as completed history.",
        document_content_unverified: "The document content is not supported by an exact conversation quote.",
        automation_trigger_invalid: "Unsupported automation trigger.",
        automation_action_invalid: "Unsupported automation action.",
        automation_keyword_missing: "The automation keyword is missing.",
        automation_keyword_unverified: "The keyword is not supported by the user message.",
        automation_time_invalid: "The automation time must use HH:MM.",
        automation_weekday_invalid: "Invalid automation weekday."
      }
    }.tap { |copy| copy["en-US"] = copy.fetch("en-GB") }.freeze
    PROPOSAL_COPY = {
      "uk-UA" => {
        clarification_needed: "Уточни, будь ласка, відсутні деталі.",
        confirmation_needed: "Підтвердити цю дію?",
        confirm: "Підтвердити",
        reject: "Відхилити",
        executing: "Виконую…",
        completed: "Виконано",
        rejected: "Відхилено",
        expired: "Пропозиція застаріла",
        failed: "Не вдалося виконати"
      },
      "de-DE" => {
        clarification_needed: "Bitte ergänze die fehlenden Angaben.",
        confirmation_needed: "Diese Aktion bestätigen?",
        confirm: "Bestätigen",
        reject: "Ablehnen",
        executing: "Wird ausgeführt…",
        completed: "Erledigt",
        rejected: "Abgelehnt",
        expired: "Vorschlag abgelaufen",
        failed: "Ausführung fehlgeschlagen"
      },
      "en-GB" => {
        clarification_needed: "Please add the missing details.",
        confirmation_needed: "Confirm this action?",
        confirm: "Confirm",
        reject: "Reject",
        executing: "Working…",
        completed: "Completed",
        rejected: "Rejected",
        expired: "Proposal expired",
        failed: "Could not complete"
      }
    }.tap { |copy| copy["en-US"] = copy.fetch("en-GB") }.freeze
    PROPOSAL_ACTION_LABELS = {
      "uk-UA" => {
        "create_task" => "Нова задача", "update_task" => "Оновлення задачі",
        "create_reminder" => "Нове нагадування", "update_reminder" => "Оновлення нагадування",
        "create_event" => "Нова подія", "update_event" => "Оновлення події",
        "create_knowledge" => "Нове знання", "update_knowledge" => "Оновлення знання",
        "create_life_log" => "Новий запис історії", "update_life_log" => "Оновлення історії",
        "create_document" => "Новий документ", "update_document" => "Оновлення документа",
        "create_automation_rule" => "Нова автоматизація", "update_automation_rule" => "Оновлення автоматизації"
      },
      "de-DE" => {
        "create_task" => "Neue Aufgabe", "update_task" => "Aufgabe aktualisieren",
        "create_reminder" => "Neue Erinnerung", "update_reminder" => "Erinnerung aktualisieren",
        "create_event" => "Neuer Termin", "update_event" => "Termin aktualisieren",
        "create_knowledge" => "Neues Wissen", "update_knowledge" => "Wissen aktualisieren",
        "create_life_log" => "Neuer Verlaufseintrag", "update_life_log" => "Verlauf aktualisieren",
        "create_document" => "Neues Dokument", "update_document" => "Dokument aktualisieren",
        "create_automation_rule" => "Neue Automatisierung", "update_automation_rule" => "Automatisierung aktualisieren"
      },
      "en-GB" => {
        "create_task" => "New task", "update_task" => "Update task",
        "create_reminder" => "New reminder", "update_reminder" => "Update reminder",
        "create_event" => "New event", "update_event" => "Update event",
        "create_knowledge" => "New knowledge", "update_knowledge" => "Update knowledge",
        "create_life_log" => "New history entry", "update_life_log" => "Update history",
        "create_document" => "New document", "update_document" => "Update document",
        "create_automation_rule" => "New automation", "update_automation_rule" => "Update automation"
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

    def proposal_copy(locale, key)
      PROPOSAL_COPY.fetch(normalize(locale) || DEFAULT_LOCALE).fetch(key)
    end

    def proposal_action_label(locale, action_kind)
      PROPOSAL_ACTION_LABELS.fetch(normalize(locale) || DEFAULT_LOCALE).fetch(action_kind, action_kind.humanize)
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
