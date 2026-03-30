class CreateFamilyKnowledge < ActiveRecord::Migration[8.1]
  def change
    create_table :family_knowledge do |t|
      t.references :family, null: false, foreign_key: true
      t.string :key, null: false
      t.text :value, null: false
      t.string :source
      t.float :confidence, default: 0.7, null: false

      t.timestamps
    end

    add_index :family_knowledge, %i[family_id updated_at]
    add_index :family_knowledge, %i[family_id confidence]
  end
end
