class CreateFamilyMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :family_members do |t|
      t.references :family, null: false, foreign_key: true
      t.string :name
      t.string :role
      t.date :birthdate
      t.jsonb :permissions

      t.timestamps
    end
  end
end
