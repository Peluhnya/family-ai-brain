class AddExecutionFieldsToAutomationRules < ActiveRecord::Migration[8.1]
  def change
    add_column :automation_rules, :template_key, :string
    add_column :automation_rules, :last_executed_at, :datetime
  end
end
