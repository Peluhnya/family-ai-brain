class AddEmbeddingToLifeLogs < ActiveRecord::Migration[8.1]
  def change
    unless extension_enabled?("vector")
      raise <<~ERROR
        PostgreSQL extension "vector" is not enabled for this database.
        Install pgvector on the database server and run:
          CREATE EXTENSION vector;
        with a superuser or database owner that has permission to create extensions.
      ERROR
    end

    add_column :life_logs, :embedding, :vector, limit: 1536
  end
end
