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

ActiveRecord::Schema.define(version: 20190525164531) do

  create_table "documents", force: :cascade do |t|
    t.string   "title",         limit: 255
    t.text     "description",   limit: 65535
    t.date     "document_date"
    t.string   "document_url",  limit: 255
    t.decimal  "version",                     precision: 10
    t.integer  "folder_id",     limit: 4
    t.integer  "user_id",       limit: 4
    t.integer  "state_id",      limit: 4
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
  end

  add_index "documents", ["folder_id"], name: "index_documents_on_folder_id", using: :btree
  add_index "documents", ["state_id"], name: "index_documents_on_state_id", using: :btree
  add_index "documents", ["user_id"], name: "index_documents_on_user_id", using: :btree

  create_table "folders", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.integer  "folder_id",  limit: 4
    t.integer  "user_id",    limit: 4
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "folders", ["folder_id"], name: "index_folders_on_folder_id", using: :btree
  add_index "folders", ["name"], name: "index_folders_on_name", unique: true, using: :btree
  add_index "folders", ["user_id"], name: "index_folders_on_user_id", using: :btree

  create_table "states", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "states", ["name"], name: "index_states_on_name", unique: true, using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "name",            limit: 255
    t.string   "password_digest", limit: 255
    t.string   "email",           limit: 255
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree

  add_foreign_key "documents", "folders"
  add_foreign_key "documents", "states"
  add_foreign_key "documents", "users"
  add_foreign_key "folders", "folders"
  add_foreign_key "folders", "users"
end