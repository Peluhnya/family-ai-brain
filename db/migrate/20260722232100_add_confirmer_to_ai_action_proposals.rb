class AddConfirmerToAiActionProposals < ActiveRecord::Migration[8.1]
  def change
    add_reference :ai_action_proposals, :confirmed_by, foreign_key: { to_table: :users }
  end
end
