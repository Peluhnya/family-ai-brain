class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :family, null: false, foreign_key: true
      t.string :title, null: false
      t.datetime :start_time, null: false
      t.datetime :end_time
      t.string :location
      t.string :external_id
      t.string :source

      t.timestamps
    end

    add_index :events, :start_time
    add_index :events, :external_id
    add_index :events, :source
  end
end
