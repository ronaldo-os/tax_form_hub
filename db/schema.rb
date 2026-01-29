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

ActiveRecord::Schema[7.2].define(version: 2026_01_28_002920) do
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
    t.string "country"
    t.index ["user_id"], name: "index_companies_on_user_id"
  end

  create_table "credit_notes", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.bigint "user_id", null: false
    t.string "credit_note_number", null: false
    t.decimal "credit_amount", precision: 12, scale: 2, null: false
    t.string "currency", null: false
    t.text "reason"
    t.string "status", default: "issued"
    t.date "issue_date", null: false
    t.string "original_invoice_number"
    t.bigint "created_by_user_id", null: false
    t.datetime "created_by_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.jsonb "reference_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_user_id"], name: "index_credit_notes_on_created_by_user_id"
    t.index ["credit_note_number"], name: "index_credit_notes_on_credit_note_number", unique: true
    t.index ["invoice_id", "status"], name: "index_credit_notes_on_invoice_and_status"
    t.index ["invoice_id"], name: "index_credit_notes_on_invoice_id"
    t.index ["user_id", "created_at"], name: "index_credit_notes_on_user_and_created_at"
    t.index ["user_id"], name: "index_credit_notes_on_user_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "recipient_company_id"
    t.string "invoice_number"
    t.date "issue_date"
    t.string "currency"
    t.jsonb "line_items_data", default: []
    t.jsonb "payment_terms", default: []
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
    t.jsonb "invoice_info", default: {}, null: false
    t.jsonb "total", default: {}, null: false
    t.string "invoice_type"
    t.string "status", default: "draft"
    t.bigint "sale_from_id"
    t.boolean "archived", default: false
    t.bigint "recurring_origin_invoice_id"
    t.string "invoice_category", default: "standard"
    t.bigint "credit_note_original_invoice_id"
    t.index ["recipient_company_id", "status"], name: "index_invoices_on_recipient_and_status"
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

  create_table "networks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_networks_on_company_id"
    t.index ["user_id", "company_id"], name: "index_networks_on_user_id_and_company_id", unique: true
    t.index ["user_id"], name: "index_networks_on_user_id"
  end

  create_table "recommendations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "company_id", null: false
    t.text "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_recommendations_on_company_id"
    t.index ["user_id"], name: "index_recommendations_on_user_id"
  end

  create_table "tax_rates", force: :cascade do |t|
    t.string "name"
    t.decimal "rate"
    t.bigint "company_id"
    t.boolean "custom"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_tax_rates_on_company_id"
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
    t.bigint "company_id", null: false
    t.bigint "invoice_id", null: false
    t.integer "user_transaction_id"
    t.index ["company_id", "archived", "created_at"], name: "index_tax_submissions_on_company_archived_created"
    t.index ["company_id"], name: "index_tax_submissions_on_company_id"
    t.index ["email", "archived", "created_at"], name: "index_tax_submissions_on_email_archived_created"
    t.index ["email", "user_transaction_id"], name: "index_tax_submissions_on_email_and_user_transaction_id"
    t.index ["invoice_id"], name: "index_tax_submissions_on_invoice_id"
  end

  create_table "units", force: :cascade do |t|
    t.string "name"
    t.bigint "company_id"
    t.boolean "custom", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_units_on_company_id"
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
  add_foreign_key "credit_notes", "invoices"
  add_foreign_key "credit_notes", "users"
  add_foreign_key "credit_notes", "users", column: "created_by_user_id"
  add_foreign_key "invoices", "invoices", column: "credit_note_original_invoice_id"
  add_foreign_key "invoices", "locations", column: "remit_to_location_id"
  add_foreign_key "invoices", "locations", column: "ship_from_location_id"
  add_foreign_key "invoices", "locations", column: "tax_representative_location_id"
  add_foreign_key "invoices", "users"
  add_foreign_key "locations", "users"
  add_foreign_key "networks", "companies"
  add_foreign_key "networks", "users"
  add_foreign_key "recommendations", "companies"
  add_foreign_key "recommendations", "users"
  add_foreign_key "tax_rates", "companies"
  add_foreign_key "tax_submissions", "companies"
  add_foreign_key "tax_submissions", "invoices"
  add_foreign_key "units", "companies"
end
