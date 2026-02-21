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

ActiveRecord::Schema[8.1].define(version: 2026_02_21_235000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "chat_messages", force: :cascade do |t|
    t.text "body", null: false
    t.bigint "chatroom_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["chatroom_id", "created_at", "id"], name: "index_chat_messages_on_chatroom_created_at_id"
    t.index ["chatroom_id"], name: "index_chat_messages_on_chatroom_id"
    t.index ["user_id"], name: "index_chat_messages_on_user_id"
    t.check_constraint "char_length(TRIM(BOTH FROM body)) > 0", name: "chk_chat_messages_body_not_blank"
    t.check_constraint "char_length(body) <= 140", name: "chk_chat_messages_body_max_140"
  end

  create_table "chatrooms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "has_unread", default: false, null: false
    t.bigint "last_sender_id"
    t.bigint "post_id", null: false
    t.bigint "reply_user_id", null: false
    t.datetime "updated_at", null: false
    t.index ["last_sender_id"], name: "index_chatrooms_on_last_sender_id"
    t.index ["post_id", "reply_user_id"], name: "index_chatrooms_on_post_id_and_reply_user_id", unique: true
    t.index ["post_id"], name: "index_chatrooms_on_post_id"
    t.index ["reply_user_id"], name: "index_chatrooms_on_reply_user_id"
  end

  create_table "filter_terms", force: :cascade do |t|
    t.string "action", default: "prohibit", null: false
    t.datetime "created_at", null: false
    t.string "term", null: false
    t.datetime "updated_at", null: false
    t.index ["term"], name: "index_filter_terms_on_term", unique: true
    t.check_constraint "action::text = ANY (ARRAY['prohibit'::character varying::text, 'support'::character varying::text])", name: "chk_filter_terms_action_valid"
    t.check_constraint "char_length(TRIM(BOTH FROM term)) > 0", name: "chk_filter_terms_term_not_blank"
  end

  create_table "matching_exclusion_terms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "term", null: false
    t.datetime "updated_at", null: false
    t.index ["term"], name: "index_matching_exclusion_terms_on_term", unique: true
    t.check_constraint "char_length(TRIM(BOTH FROM term)) > 0", name: "chk_matching_exclusion_terms_term_not_blank"
  end

  create_table "post_terms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "post_id", null: false
    t.bigint "term_id", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id", "term_id"], name: "index_post_terms_on_post_id_and_term_id", unique: true
    t.index ["post_id"], name: "index_post_terms_on_post_id"
    t.index ["term_id", "post_id"], name: "index_post_terms_on_term_id_and_post_id"
    t.index ["term_id"], name: "index_post_terms_on_term_id"
  end

  create_table "posts", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "sentiment_label"
    t.float "sentiment_score"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["created_at", "id"], name: "index_posts_on_created_at_and_id"
    t.index ["user_id", "created_at"], name: "index_posts_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_posts_on_user_id"
    t.check_constraint "char_length(TRIM(BOTH FROM body)) > 0", name: "chk_posts_body_not_blank"
    t.check_constraint "char_length(body) <= 140", name: "chk_posts_body_max_140"
    t.check_constraint "sentiment_label IS NULL OR (sentiment_label::text = ANY (ARRAY['pos'::character varying::text, 'neg'::character varying::text]))", name: "chk_posts_sentiment_label_valid"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "terms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "term", null: false
    t.datetime "updated_at", null: false
    t.index ["term"], name: "index_terms_on_term", unique: true
    t.check_constraint "char_length(TRIM(BOTH FROM term)) > 0", name: "chk_terms_term_not_blank"
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

  add_foreign_key "chat_messages", "chatrooms"
  add_foreign_key "chat_messages", "users"
  add_foreign_key "chatrooms", "posts"
  add_foreign_key "chatrooms", "users", column: "last_sender_id"
  add_foreign_key "chatrooms", "users", column: "reply_user_id"
  add_foreign_key "post_terms", "posts"
  add_foreign_key "post_terms", "terms"
  add_foreign_key "posts", "users"
  add_foreign_key "sessions", "users"
end
