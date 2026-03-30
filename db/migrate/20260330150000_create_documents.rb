class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :family, null: false, foreign_key: true
      t.string :title, null: false
      t.text :content, null: false
      t.vector :embedding, limit: 1536

      t.timestamps
    end

    add_index :documents, :created_at
  end
end
