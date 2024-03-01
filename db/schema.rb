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

ActiveRecord::Schema[7.1].define(version: 2024_03_01_014132) do
  create_schema "heroku_ext"

  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_stat_statements"
  enable_extension "pg_trgm"
  enable_extension "plpgsql"
  enable_extension "unaccent"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

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

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "bookmarks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "user_id"], name: "index_bookmarks_on_product_id_and_user_id", unique: true
    t.index ["product_id"], name: "index_bookmarks_on_product_id"
    t.index ["user_id"], name: "index_bookmarks_on_user_id"
  end

  create_table "brands", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "discontinued", default: false
    t.string "slug"
    t.integer "products_count"
    t.string "website"
    t.string "country_code"
    t.string "full_name"
    t.integer "founded_year"
    t.text "description"
    t.integer "discontinued_day"
    t.integer "discontinued_month"
    t.integer "discontinued_year"
    t.integer "founded_month"
    t.integer "founded_day"
    t.index "\"left\"(lower((name)::text), 1)", name: "index_brands_name_prefix"
    t.index "lower((name)::text)", name: "index_brands_on_name", unique: true
    t.index ["name"], name: "gin_index_brands_on_name", opclass: :gin_trgm_ops, using: :gin
    t.index ["slug"], name: "index_brands_on_slug", unique: true
  end

  create_table "brands_sub_categories", id: false, force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.bigint "sub_category_id", null: false
    t.index ["brand_id", "sub_category_id"], name: "index_brands_sub_categories_on_brand_id_and_sub_category_id", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.integer "order"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "custom_attributes", force: :cascade do |t|
    t.jsonb "options"
  end

  create_table "custom_attributes_sub_categories", id: false, force: :cascade do |t|
    t.bigint "sub_category_id", null: false
    t.bigint "custom_attribute_id", null: false
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "prev_owneds", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.index ["product_id", "user_id"], name: "index_prev_owneds_on_product_id_and_user_id", unique: true
    t.index ["product_id"], name: "index_prev_owneds_on_product_id"
    t.index ["user_id"], name: "index_prev_owneds_on_user_id"
  end

  create_table "products", force: :cascade do |t|
    t.citext "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "brand_id", null: false
    t.boolean "discontinued", default: false
    t.string "slug"
    t.integer "release_day"
    t.integer "release_month"
    t.integer "release_year"
    t.text "description"
    t.jsonb "custom_attributes"
    t.decimal "price", precision: 12, scale: 4
    t.string "price_currency"
    t.integer "discontinued_year"
    t.integer "discontinued_month"
    t.integer "discontinued_day"
    t.index "\"left\"(lower((name)::text), 1)", name: "index_products_name_prefix"
    t.index ["custom_attributes"], name: "index_products_on_custom_attributes", using: :gin
    t.index ["name", "brand_id"], name: "index_products_on_name_and_brand_id", unique: true
    t.index ["name"], name: "gin_index_products_on_name", opclass: :gin_trgm_ops, using: :gin
    t.index ["slug"], name: "index_products_on_slug"
  end

  create_table "products_setups", id: false, force: :cascade do |t|
    t.bigint "setup_id", null: false
    t.bigint "product_id", null: false
  end

  create_table "products_sub_categories", id: false, force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "sub_category_id", null: false
  end

  create_table "products_users", id: false, force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "user_id", null: false
  end

  create_table "setups", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["name", "user_id"], name: "index_setups_on_name_and_user_id", unique: true
  end

  create_table "sub_categories", force: :cascade do |t|
    t.string "name"
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.index ["category_id"], name: "index_sub_categories_on_category_id"
    t.index ["slug"], name: "index_sub_categories_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "profile_visibility", default: 0
    t.string "user_name", null: false
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.index "lower((email)::text)", name: "index_users_on_email", unique: true
    t.index "lower((user_name)::text)", name: "index_users_on_user_name", unique: true
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.datetime "created_at"
    t.text "object_changes"
    t.text "comment"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bookmarks", "products"
  add_foreign_key "bookmarks", "users"
  add_foreign_key "products", "brands"
  add_foreign_key "sub_categories", "categories"
end
