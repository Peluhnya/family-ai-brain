class AddAiProviderToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :ai_provider, :string, default: "openai", null: false
  end
end
