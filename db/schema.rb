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

ActiveRecord::Schema[7.2].define(version: 2025_07_09_073216) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  create_table "companies", force: :cascade do |t|
    t.string "name"
    t.string "website"
    t.string "industry"
    t.string "ownership"
    t.string "address"
    t.string "phone"
    t.text "description"
    t.string "size"
    t.string "share_capital"
    t.string "registration_address"
    t.string "email_address"
    t.string "company_id_type"
    t.string "tax_id_type"
    t.string "gln"
    t.string "company_id_number"
    t.string "tax_id_number"
    t.string "internal_identifier"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_companies_on_user_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.string "invoice_number"
    t.date "issue_date"
    t.string "currency"
    t.date "payment_due_date"
    t.integer "item_id"
    t.text "description"
    t.integer "quantity"
    t.string "unit"
    t.decimal "price_per_unit"
    t.decimal "tax"
    t.decimal "total"
    t.text "recipient_note"
    t.string "header_type"
    t.text "header_description"
    t.integer "header_qty"
    t.string "header_unit"
    t.decimal "header_tax"
    t.decimal "header_total"
    t.decimal "pricing_discount"
    t.string "bank_name"
    t.string "bank_sort_code"
    t.string "bank_account_number"
    t.string "bank_account_holder"
    t.string "bank_street_name"
    t.string "bank_builder_number"
    t.string "bank_city"
    t.string "bank_zip_code"
    t.string "bank_region"
    t.string "bank_address_line"
    t.string "bank_country"
    t.text "bank_payment_note"
    t.string "attachment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "locations", force: :cascade do |t|
    t.string "location_type"
    t.string "location_name"
    t.string "country"
    t.string "company_name"
    t.string "tax_number"
    t.string "post_box"
    t.string "street"
    t.string "building"
    t.string "additional_street"
    t.string "zip_code"
    t.string "city"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_locations_on_user_id"
  end

  create_table "tax_submissions", force: :cascade do |t|
    t.string "email"
    t.text "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "reviewed"
    t.boolean "processed"
    t.boolean "archived"
    t.string "company_name"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "user"
    t.integer "company_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "companies", "users"
  add_foreign_key "locations", "users"
end
