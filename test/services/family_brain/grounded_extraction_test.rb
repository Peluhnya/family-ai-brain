require "test_helper"

module FamilyBrain
  class GroundedExtractionTest < ActiveSupport::TestCase
    test "accepts only meaningful phrases" do
      assert GroundedExtraction.meaningful_phrase?("Подзвонити мамі")
      assert_not GroundedExtraction.meaningful_phrase?("Do")
      assert_not GroundedExtraction.meaningful_phrase?("Пам'ятайте (Remember)")

      assert GroundedExtraction.meaningful_title?("Відпустка")
      assert GroundedExtraction.meaningful_title?("Urlaub")
      assert_not GroundedExtraction.meaningful_title?("Do")
    end

    test "requires exact evidence from the user text" do
      text = "Нагадай мені завтра ввечері подзвонити мамі"

      assert GroundedExtraction.evidence_present?(text, "нагадай мені завтра ввечері подзвонити мамі")
      assert_not GroundedExtraction.evidence_present?(text, "подзвонити татові")
      assert GroundedExtraction.evidence_fragment_present?("о 10", "о 10")
      assert_not GroundedExtraction.evidence_present?("о 10", "о 10")
    end

    test "checks that the title is grounded in the evidence quote" do
      evidence = "нагадай мені завтра ввечері подзвонити мамі"

      assert GroundedExtraction.title_grounded_in_evidence?("Подзвонити мамі", evidence)
      assert_not GroundedExtraction.title_grounded_in_evidence?("Перевірка інформації", evidence)
      assert_equal "Відпустку", GroundedExtraction.grounded_title(
        "Нагадування про відпустку",
        "я маю відпустку з 10 червня"
      )
      assert_nil GroundedExtraction.grounded_title("Перевірка інформації", evidence)
    end

    test "detects reminder and temporal intent" do
      assert GroundedExtraction.reminder_intent?("Нагадай мені завтра про садочок")
      assert GroundedExtraction.reminder_intent?("Remind me tomorrow to call Mum")
      assert GroundedExtraction.reminder_intent?("Erinnere mich morgen an den Termin")
      assert_not GroundedExtraction.reminder_intent?("Склади план дня")

      assert GroundedExtraction.temporal_reference?("Зустріч завтра о 19:00")
      assert GroundedExtraction.temporal_reference?("Meeting tomorrow at 7 pm", locale: "en-GB")
      assert GroundedExtraction.temporal_reference?("Termin morgen um 19 Uhr", locale: "de-DE")
      assert_not GroundedExtraction.temporal_reference?("Купити молоко")
    end

    test "detects multilingual action modifiers" do
      assert GroundedExtraction.actionable?("I need to pay the loan")
      assert GroundedExtraction.actionable?("Ich muss den Kredit bezahlen")
      assert GroundedExtraction.only_reminder?("Only set a reminder")
      assert GroundedExtraction.only_reminder?("Nur eine Erinnerung")
      assert GroundedExtraction.no_reminder?("Ohne Erinnerung")
    end
  end
end
