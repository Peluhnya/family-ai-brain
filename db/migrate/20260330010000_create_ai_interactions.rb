class CreateAiInteractions < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_interactions do |t|
      t.references :family, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false
      t.string :model
      t.integer :tokens

      t.timestamps
    end

    add_index :ai_interactions, %i[family_id created_at]
  end
end
