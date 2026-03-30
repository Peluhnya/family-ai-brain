class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.references :family, null: false, foreign_key: true
      t.bigint :assigned_to
      t.string :title, null: false
      t.text :description
      t.datetime :due_at
      t.string :status, null: false, default: "pending"
      t.integer :priority, null: false, default: 2

      t.timestamps
    end

    add_foreign_key :tasks, :family_members, column: :assigned_to
    add_index :tasks, :status
    add_index :tasks, :due_at
    add_index :tasks, :priority
  end
end
