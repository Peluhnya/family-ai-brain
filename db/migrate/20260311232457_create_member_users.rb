class CreateMemberUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :member_users do |t|
      t.references :family_member, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role

      t.timestamps
    end
  end
end
