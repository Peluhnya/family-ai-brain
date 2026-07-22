class CreateAutomationRuleExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :automation_rule_executions do |t|
      t.references :automation_rule, null: false, foreign_key: true
      t.references :family, null: false, foreign_key: true
      t.string :action_type, null: false
      t.string :source_type
      t.bigint :source_id
      t.string :status, null: false, default: "completed"
      t.string :context_digest
      t.string :created_entity_type
      t.bigint :created_entity_id

      t.timestamps
    end

    add_index :automation_rule_executions,
      [:automation_rule_id, :source_type, :source_id, :action_type],
      unique: true,
      where: "source_type IS NOT NULL AND source_id IS NOT NULL",
      name: "idx_automation_rule_executions_uniqueness"

    add_index :automation_rule_executions, [:family_id, :created_at]
  end
end
