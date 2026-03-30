class CreateReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :reminders do |t|
      t.references :family, null: false, foreign_key: true
      t.string :title, null: false
      t.datetime :trigger_at, null: false
      t.string :channel, null: false, default: "app"
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :reminders, :trigger_at
    add_index :reminders, :status
    add_index :reminders, :channel
  end
end
