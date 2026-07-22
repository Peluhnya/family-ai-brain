class PruneAiEffectsJob < ApplicationJob
  queue_as :maintenance

  ROUTINE_RETENTION_DAYS = 30
  FAILURE_RETENTION_DAYS = 90
  DEFAULT_BATCH_SIZE = 1_000

  def perform(now: Time.current)
    counts = {
      routine: delete_in_batches(AiEffect.routine_outcomes.created_before(now - routine_retention)),
      failed: delete_in_batches(AiEffect.failures.created_before(now - failure_retention)),
      pending: delete_in_batches(AiEffect.pending.created_before(now - routine_retention))
    }

    Rails.logger.info(
      "ai_effect_retention_cleanup " \
      "routine_deleted=#{counts[:routine]} failed_deleted=#{counts[:failed]} pending_deleted=#{counts[:pending]}"
    )

    counts
  end

  private

  def routine_retention
    retention_days("AI_EFFECT_ROUTINE_RETENTION_DAYS", ROUTINE_RETENTION_DAYS).days
  end

  def failure_retention
    retention_days("AI_EFFECT_FAILURE_RETENTION_DAYS", FAILURE_RETENTION_DAYS).days
  end

  def batch_size
    ENV.fetch("AI_EFFECT_PRUNE_BATCH_SIZE", DEFAULT_BATCH_SIZE).to_i.clamp(100, 10_000)
  end

  def retention_days(environment_key, default)
    ENV.fetch(environment_key, default).to_i.clamp(1, 3_650)
  end

  def delete_in_batches(relation)
    relation.in_batches(of: batch_size).sum { |batch| batch.delete_all }
  end
end
