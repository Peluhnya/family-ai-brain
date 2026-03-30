class AddAiSettingsToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :ai_access_mode, :string, default: "app_default", null: false
    add_column :accounts, :ai_api_key, :text
    add_column :accounts, :ai_api_base, :string
    add_column :accounts, :ai_model, :string
  end
end
