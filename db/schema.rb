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

ActiveRecord::Schema[7.2].define(version: 2025_07_18_100038) do
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
    t.bigint "user_id"
    t.string "recipient_company_id"
    t.string "invoice_number"
    t.date "issue_date"
    t.string "currency"
    t.jsonb "line_items_data", default: []
    t.jsonb "payment_terms", default: []
    t.jsonb "header_charge_discount_tax", default: []
    t.jsonb "price_adjustments", default: []
    t.text "recipient_note"
    t.string "delivery_details_country"
    t.string "delivery_details_postbox"
    t.string "delivery_details_street"
    t.string "delivery_details_number"
    t.string "delivery_details_locality_name"
    t.string "delivery_details_zip_code"
    t.string "delivery_details_city"
    t.string "delivery_details_gln"
    t.string "delivery_details_company_name"
    t.string "delivery_details_tax_id"
    t.string "delivery_details_tax_number"
    t.bigint "ship_from_location_id"
    t.bigint "remit_to_location_id"
    t.bigint "tax_representative_location_id"
    t.text "message"
    t.text "footer_notes"
    t.boolean "save_notes_for_future", default: false
    t.boolean "save_footer_notes_for_future", default: false
    t.boolean "save_payment_terms_for_future", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["remit_to_location_id"], name: "index_invoices_on_remit_to_location_id"
    t.index ["ship_from_location_id"], name: "index_invoices_on_ship_from_location_id"
    t.index ["tax_representative_location_id"], name: "index_invoices_on_tax_representative_location_id"
    t.index ["user_id"], name: "index_invoices_on_user_id"
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
  add_foreign_key "invoices", "locations", column: "remit_to_location_id"
  add_foreign_key "invoices", "locations", column: "ship_from_location_id"
  add_foreign_key "invoices", "locations", column: "tax_representative_location_id"
  add_foreign_key "invoices", "users"
  add_foreign_key "locations", "users"
end
