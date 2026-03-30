require "test_helper"

module FamilyBrain
  class GroundedExtractionTest < ActiveSupport::TestCase
    test "accepts only meaningful phrases" do
      assert GroundedExtraction.meaningful_phrase?("Подзвонити мамі")
      assert_not GroundedExtraction.meaningful_phrase?("Do")
      assert_not GroundedExtraction.meaningful_phrase?("Пам'ятайте (Remember)")
    end

    test "requires exact evidence from the user text" do
      text = "Нагадай мені завтра ввечері подзвонити мамі"

      assert GroundedExtraction.evidence_present?(text, "нагадай мені завтра ввечері подзвонити мамі")
      assert_not GroundedExtraction.evidence_present?(text, "подзвонити татові")
    end

    test "checks that the title is grounded in the evidence quote" do
      evidence = "нагадай мені завтра ввечері подзвонити мамі"

      assert GroundedExtraction.title_grounded_in_evidence?("Подзвонити мамі", evidence)
      assert_not GroundedExtraction.title_grounded_in_evidence?("Перевірка інформації", evidence)
    end

    test "detects reminder and temporal intent" do
      assert GroundedExtraction.reminder_intent?("Нагадай мені завтра про садочок")
      assert_not GroundedExtraction.reminder_intent?("Склади план дня")

      assert GroundedExtraction.temporal_reference?("Зустріч завтра о 19:00")
      assert_not GroundedExtraction.temporal_reference?("Купити молоко")
    end
  end
end
