require "test_helper"

class PruneAiEffectsJobTest < ActiveSupport::TestCase
  setup do
    @family = families(:one)
    @now = Time.zone.local(2026, 7, 22, 12)
  end

  test "prunes routine outcomes after 30 days and failures after 90 days" do
    old_completed = create_effect(status: "completed", age: 31.days)
    old_skipped = create_effect(status: "skipped", age: 31.days)
    recent_completed = create_effect(status: "completed", age: 29.days)
    old_failed = create_effect(status: "failed", age: 91.days)
    recent_failed = create_effect(status: "failed", age: 89.days)
    old_pending = create_effect(status: "pending", age: 31.days)

    counts = PruneAiEffectsJob.perform_now(now: @now)

    assert_equal({ routine: 2, failed: 1, pending: 1 }, counts)
    assert_not AiEffect.exists?(old_completed.id)
    assert_not AiEffect.exists?(old_skipped.id)
    assert AiEffect.exists?(recent_completed.id)
    assert_not AiEffect.exists?(old_failed.id)
    assert AiEffect.exists?(recent_failed.id)
    assert_not AiEffect.exists?(old_pending.id)
  end

  private

  def create_effect(status:, age:)
    interaction = @family.ai_interactions.create!(
      role: "user",
      content: "retention test #{status} #{age.to_i}",
      user: users(:one),
      model: "human"
    )

    @family.ai_effects.create!(
      source_ai_interaction: interaction,
      action_type: "create_task",
      action_fingerprint: SecureRandom.hex(32),
      status: status,
      error_message: status == "failed" ? "Test failure" : nil,
      created_at: @now - age,
      updated_at: @now - age
    )
  end
end
