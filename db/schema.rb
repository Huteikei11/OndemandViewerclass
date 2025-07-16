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

ActiveRecord::Schema[8.0].define(version: 2025_07_16_024307) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "notes", force: :cascade do |t|
    t.text "content"
    t.integer "time_position"
    t.integer "video_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["video_id"], name: "index_notes_on_video_id"
  end

  create_table "options", force: :cascade do |t|
    t.text "content"
    t.boolean "is_correct"
    t.integer "question_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id"], name: "index_options_on_question_id"
  end

  create_table "questions", force: :cascade do |t|
    t.text "content"
    t.text "answer"
    t.string "question_type"
    t.integer "time_position"
    t.integer "video_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "show_answer"
    t.index ["video_id"], name: "index_questions_on_video_id"
  end

  create_table "user_responses", force: :cascade do |t|
    t.text "user_answer"
    t.boolean "is_correct"
    t.integer "question_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "response_time"
    t.integer "user_id"
    t.integer "selected_option_id"
    t.index ["question_id"], name: "index_user_responses_on_question_id"
    t.index ["user_id"], name: "index_user_responses_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "video_accesses", force: :cascade do |t|
    t.integer "video_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_video_accesses_on_user_id"
    t.index ["video_id"], name: "index_video_accesses_on_video_id"
  end

  create_table "video_managers", force: :cascade do |t|
    t.integer "video_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_video_managers_on_user_id"
    t.index ["video_id"], name: "index_video_managers_on_video_id"
  end

  create_table "videos", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "creator_id"
    t.string "password"
    t.boolean "is_private", default: false
    t.index ["creator_id"], name: "index_videos_on_creator_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "notes", "videos"
  add_foreign_key "options", "questions"
  add_foreign_key "questions", "videos"
  add_foreign_key "user_responses", "questions"
  add_foreign_key "user_responses", "users"
  add_foreign_key "video_accesses", "users"
  add_foreign_key "video_accesses", "videos"
  add_foreign_key "video_managers", "users"
  add_foreign_key "video_managers", "videos"
  add_foreign_key "videos", "users", column: "creator_id"
end
