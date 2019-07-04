# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20190528071907) do

  create_table "documents", force: :cascade do |t|
    t.string   "title"
    t.text     "description"
    t.date     "document_date"
    t.string   "document_url"
    t.decimal  "version"
    t.integer  "folder_id"
    t.integer  "user_id"
    t.integer  "state_id"
    t.integer  "person_id"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "documents", ["folder_id"], name: "index_documents_on_folder_id"
  add_index "documents", ["person_id"], name: "index_documents_on_person_id"
  add_index "documents", ["state_id"], name: "index_documents_on_state_id"
  add_index "documents", ["user_id"], name: "index_documents_on_user_id"

  create_table "documenttags", force: :cascade do |t|
    t.integer  "document_id"
    t.integer  "tag_id"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  add_index "documenttags", ["document_id"], name: "index_documenttags_on_document_id"
  add_index "documenttags", ["tag_id"], name: "index_documenttags_on_tag_id"

  create_table "folders", force: :cascade do |t|
    t.string   "name"
    t.integer  "folder_id"
    t.integer  "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "folders", ["folder_id"], name: "index_folders_on_folder_id"
  add_index "folders", ["name"], name: "index_folders_on_name", unique: true
  add_index "folders", ["user_id"], name: "index_folders_on_user_id"

  create_table "people", force: :cascade do |t|
    t.string   "name"
    t.integer  "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "states", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "states", ["name"], name: "index_states_on_name", unique: true

  create_table "tags", force: :cascade do |t|
    t.string   "name"
    t.integer  "user_id"
    t.string   "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "name"
    t.string   "password_digest"
    t.string   "email"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true

end
