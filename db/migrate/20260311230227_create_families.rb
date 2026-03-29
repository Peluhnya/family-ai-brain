class CreateFamilies < ActiveRecord::Migration[8.1]
  def change
    create_table :families do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name
      t.string :timezone
      t.string :locale

      t.timestamps
    end
  end
end
