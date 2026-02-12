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

ActiveRecord::Schema[8.1].define(version: 2026_02_12_110000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "filter_terms", force: :cascade do |t|
    t.string "action", default: "prohibit", null: false
    t.datetime "created_at", null: false
    t.string "term", null: false
    t.datetime "updated_at", null: false
    t.index ["term"], name: "index_filter_terms_on_term", unique: true
    t.check_constraint "action::text = ANY (ARRAY['prohibit'::character varying, 'support'::character varying]::text[])", name: "chk_filter_terms_action_valid"
    t.check_constraint "char_length(TRIM(BOTH FROM term)) > 0", name: "chk_filter_terms_term_not_blank"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "privacy_accepted_at", null: false
    t.string "privacy_version", null: false
    t.datetime "terms_accepted_at", null: false
    t.string "terms_version", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "char_length(TRIM(BOTH FROM privacy_version)) > 0", name: "chk_users_privacy_version_not_blank"
    t.check_constraint "char_length(TRIM(BOTH FROM terms_version)) > 0", name: "chk_users_terms_version_not_blank"
  end

  add_foreign_key "sessions", "users"
end
