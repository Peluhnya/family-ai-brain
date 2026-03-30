class RunDueAutomationRulesJob < ApplicationJob
  queue_as :default

  def perform
    Family.includes(:automation_rules).find_each do |family|
      FamilyBrain::AutomationSchedulerService.new(family: family).due_rules.each do |rule|
        AutomationRuleExecutionJob.perform_later(rule.id)
      end
    end
  end
end
