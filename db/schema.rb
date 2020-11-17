# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_05_28_071907) do

  create_table "documents", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.date "document_date"
    t.string "document_url"
    t.decimal "version"
    t.text "document_text"
    t.integer "folder_id"
    t.integer "user_id"
    t.integer "state_id"
    t.integer "person_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["folder_id"], name: "index_documents_on_folder_id"
    t.index ["person_id"], name: "index_documents_on_person_id"
    t.index ["state_id"], name: "index_documents_on_state_id"
    t.index ["user_id"], name: "index_documents_on_user_id"
  end

  create_table "documenttags", force: :cascade do |t|
    t.integer "document_id"
    t.integer "tag_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_documenttags_on_document_id"
    t.index ["tag_id"], name: "index_documenttags_on_tag_id"
  end

  create_table "folders", force: :cascade do |t|
    t.string "name"
    t.integer "folder_id"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["folder_id"], name: "index_folders_on_folder_id"
    t.index ["name"], name: "index_folders_on_name", unique: true
    t.index ["user_id"], name: "index_folders_on_user_id"
  end

  create_table "people", force: :cascade do |t|
    t.string "name"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "states", force: :cascade do |t|
    t.string "name"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_states_on_name", unique: true
  end

  create_table "tags", force: :cascade do |t|
    t.string "name"
    t.integer "user_id"
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "password_digest"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "documents", "folders", on_delete: :nullify
  add_foreign_key "documents", "people", on_delete: :nullify
  add_foreign_key "documents", "states", on_delete: :nullify
  add_foreign_key "documents", "users", on_delete: :cascade
  add_foreign_key "documenttags", "documents"
  add_foreign_key "documenttags", "tags"
  add_foreign_key "folders", "folders"
  add_foreign_key "folders", "users"
end
