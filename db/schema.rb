# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_30_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "accounts", force: :cascade do |t|
    t.boolean "active"
    t.string "ai_access_mode", default: "app_default", null: false
    t.string "ai_api_base"
    t.text "ai_api_key"
    t.string "ai_model"
    t.string "ai_provider", default: "openai", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "email"
    t.string "name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  create_table "ai_interactions", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "family_id", null: false
    t.string "model"
    t.string "role", null: false
    t.integer "tokens"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["family_id", "created_at"], name: "index_ai_interactions_on_family_id_and_created_at"
    t.index ["family_id"], name: "index_ai_interactions_on_family_id"
    t.index ["user_id"], name: "index_ai_interactions_on_user_id"
  end

  create_table "automation_rules", force: :cascade do |t|
    t.jsonb "action_config", default: {}, null: false
    t.string "action_type", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "family_id", null: false
    t.datetime "last_executed_at"
    t.string "name", null: false
    t.string "template_key"
    t.jsonb "trigger_config", default: {}, null: false
    t.string "trigger_type", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id", "active"], name: "index_automation_rules_on_family_id_and_active"
    t.index ["family_id"], name: "index_automation_rules_on_family_id"
  end

  create_table "calendar_connections", force: :cascade do |t|
    t.text "access_token"
    t.boolean "active", default: true, null: false
    t.string "connection_fingerprint"
    t.datetime "created_at", null: false
    t.string "display_name"
    t.bigint "family_id", null: false
    t.text "last_error"
    t.datetime "last_synced_at"
    t.string "provider", null: false
    t.text "refresh_token"
    t.string "remote_calendar_id"
    t.string "remote_calendar_key"
    t.jsonb "settings", default: {}, null: false
    t.text "sync_cursor"
    t.datetime "updated_at", null: false
    t.index ["family_id", "connection_fingerprint"], name: "index_calendar_connections_on_family_and_fingerprint", unique: true, where: "(connection_fingerprint IS NOT NULL)"
    t.index ["family_id"], name: "index_calendar_connections_on_family_id"
    t.index ["provider"], name: "index_calendar_connections_on_provider"
  end

  create_table "documents", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.vector "embedding", limit: 1536
    t.bigint "family_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_documents_on_created_at"
    t.index ["family_id"], name: "index_documents_on_family_id"
  end

  create_table "events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "end_time"
    t.string "external_id"
    t.bigint "family_id", null: false
    t.string "location"
    t.string "source"
    t.string "source_key"
    t.datetime "start_time", null: false
    t.string "sync_fingerprint"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_events_on_external_id"
    t.index ["family_id", "sync_fingerprint"], name: "index_events_on_family_and_sync_fingerprint", unique: true, where: "(sync_fingerprint IS NOT NULL)"
    t.index ["family_id"], name: "index_events_on_family_id"
    t.index ["source"], name: "index_events_on_source"
    t.index ["source_key"], name: "index_events_on_source_key"
    t.index ["start_time"], name: "index_events_on_start_time"
  end

  create_table "families", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "locale"
    t.string "name"
    t.string "timezone"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_families_on_account_id"
  end

  create_table "family_knowledge", force: :cascade do |t|
    t.float "confidence", default: 0.7, null: false
    t.datetime "created_at", null: false
    t.vector "embedding", limit: 1536
    t.bigint "family_id", null: false
    t.string "key", null: false
    t.string "source"
    t.datetime "updated_at", null: false
    t.text "value", null: false
    t.index ["family_id", "confidence"], name: "index_family_knowledge_on_family_id_and_confidence"
    t.index ["family_id", "updated_at"], name: "index_family_knowledge_on_family_id_and_updated_at"
    t.index ["family_id"], name: "index_family_knowledge_on_family_id"
  end

  create_table "family_members", force: :cascade do |t|
    t.date "birthdate"
    t.datetime "created_at", null: false
    t.bigint "family_id", null: false
    t.string "name"
    t.jsonb "permissions"
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_family_members_on_family_id"
  end

  create_table "life_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.vector "embedding", limit: 1536
    t.string "event_type", null: false
    t.bigint "family_id", null: false
    t.datetime "happened_at"
    t.float "importance", default: 0.5, null: false
    t.text "raw_text"
    t.text "summary", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id", "happened_at"], name: "index_life_logs_on_family_id_and_happened_at"
    t.index ["family_id", "importance"], name: "index_life_logs_on_family_id_and_importance"
    t.index ["family_id"], name: "index_life_logs_on_family_id"
  end

  create_table "member_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "family_member_id", null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["family_member_id"], name: "index_member_users_on_family_member_id"
    t.index ["user_id"], name: "index_member_users_on_user_id"
  end

  create_table "reminders", force: :cascade do |t|
    t.string "channel", default: "app", null: false
    t.datetime "created_at", null: false
    t.bigint "family_id", null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "trigger_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel"], name: "index_reminders_on_channel"
    t.index ["family_id"], name: "index_reminders_on_family_id"
    t.index ["status"], name: "index_reminders_on_status"
    t.index ["trigger_at"], name: "index_reminders_on_trigger_at"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "assigned_to"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "due_at"
    t.bigint "family_id", null: false
    t.integer "priority", default: 2, null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["due_at"], name: "index_tasks_on_due_at"
    t.index ["family_id"], name: "index_tasks_on_family_id"
    t.index ["priority"], name: "index_tasks_on_priority"
    t.index ["status"], name: "index_tasks_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "accounts", "users"
  add_foreign_key "ai_interactions", "families"
  add_foreign_key "ai_interactions", "users"
  add_foreign_key "automation_rules", "families"
  add_foreign_key "calendar_connections", "families"
  add_foreign_key "documents", "families"
  add_foreign_key "events", "families"
  add_foreign_key "families", "accounts"
  add_foreign_key "family_knowledge", "families"
  add_foreign_key "family_members", "families"
  add_foreign_key "life_logs", "families"
  add_foreign_key "member_users", "family_members"
  add_foreign_key "member_users", "users"
  add_foreign_key "reminders", "families"
  add_foreign_key "tasks", "families"
  add_foreign_key "tasks", "family_members", column: "assigned_to"
end
