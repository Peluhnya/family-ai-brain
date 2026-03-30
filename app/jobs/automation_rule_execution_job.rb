class AutomationRuleExecutionJob < ApplicationJob
  queue_as :default

  def perform(rule_id, context = {})
    rule = AutomationRule.find(rule_id)
    FamilyBrain::AutomationExecutionService.new(rule: rule, context: context.symbolize_keys).call
  end
end
