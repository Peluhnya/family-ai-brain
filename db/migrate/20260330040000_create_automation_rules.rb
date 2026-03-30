class CreateAutomationRules < ActiveRecord::Migration[8.1]
  def change
    create_table :automation_rules do |t|
      t.references :family, null: false, foreign_key: true
      t.string :name, null: false
      t.string :trigger_type, null: false
      t.jsonb :trigger_config, default: {}, null: false
      t.string :action_type, null: false
      t.jsonb :action_config, default: {}, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :automation_rules, %i[family_id active]
  end
end
