class CreateLifeLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :life_logs do |t|
      t.references :family, null: false, foreign_key: true
      t.string :event_type, null: false
      t.text :summary, null: false
      t.text :raw_text
      t.float :importance, default: 0.5, null: false
      t.datetime :happened_at

      t.timestamps
    end

    add_index :life_logs, %i[family_id happened_at]
    add_index :life_logs, %i[family_id importance]
  end
end
