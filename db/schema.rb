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

ActiveRecord::Schema[8.0].define(version: 2025_07_19_113502) do
  create_schema "_heroku"
  create_schema "heroku_ext"

  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"
  enable_extension "pg_trgm"
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

  create_table "active_analytics_browsers_per_days", force: :cascade do |t|
    t.string "site", null: false
    t.string "name", null: false
    t.string "version", null: false
    t.date "date", null: false
    t.bigint "total", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["date", "site", "name", "version"], name: "idx_on_date_site_name_version_eeccd0371c"
  end

  create_table "active_analytics_views_per_days", force: :cascade do |t|
    t.string "site", null: false
    t.string "page", null: false
    t.date "date", null: false
    t.bigint "total", default: 1, null: false
    t.string "referrer_host"
    t.string "referrer_path"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["date", "site", "page"], name: "index_active_analytics_views_per_days_on_date_and_site_and_page"
    t.index ["date", "site", "referrer_host", "referrer_path"], name: "index_views_per_days_on_date_site_referrer_host_referrer_path"
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
    t.index ["email"], name: "index_admin_users_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "app_news", force: :cascade do |t|
    t.text "text", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "app_news_users", id: false, force: :cascade do |t|
    t.bigint "app_news_id", null: false
    t.bigint "user_id", null: false
    t.index ["app_news_id", "user_id"], name: "index_app_news_users_on_app_news_id_and_user_id", unique: true
  end

  create_table "bookmark_lists", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "user_id"], name: "index_bookmark_lists_on_name_and_user_id", unique: true
    t.index ["user_id"], name: "index_bookmark_lists_on_user_id"
  end

  create_table "bookmarks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "product_variant_id"
    t.bigint "bookmark_list_id"
    t.index ["bookmark_list_id"], name: "index_bookmarks_on_bookmark_list_id"
    t.index ["product_id", "user_id", "product_variant_id"], name: "idx_on_product_id_user_id_product_variant_id_24cc95bae4", unique: true
    t.index ["user_id"], name: "index_bookmarks_on_user_id"
  end

  create_table "brands", force: :cascade do |t|
    t.citext "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "discontinued"
    t.citext "slug", null: false
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
    t.index "\"left\"((name)::text, 1)", name: "index_brands_name_prefix"
    t.index ["country_code"], name: "index_brands_on_country_code"
    t.index ["discontinued"], name: "index_brands_on_discontinued"
    t.index ["name"], name: "gin_index_brands_on_name", opclass: :gin_trgm_ops, using: :gin
    t.index ["name"], name: "index_brands_on_name", unique: true
    t.index ["slug"], name: "index_brands_on_slug", unique: true
  end

  create_table "brands_sub_categories", id: false, force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.bigint "sub_category_id", null: false
    t.index ["brand_id", "sub_category_id"], name: "index_brands_sub_categories_on_brand_id_and_sub_category_id", unique: true
    t.index ["brand_id"], name: "index_brands_sub_categories_on_brand_id"
    t.index ["sub_category_id"], name: "index_brands_sub_categories_on_sub_category_id"
  end

  create_table "categories", force: :cascade do |t|
    t.citext "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.citext "slug", null: false
    t.integer "order"
    t.integer "column"
    t.index ["name"], name: "index_categories_name", unique: true
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "custom_attributes", force: :cascade do |t|
    t.jsonb "options"
    t.string "label"
    t.string "input_type"
    t.string "inputs", default: [], array: true
    t.string "units", default: [], array: true
    t.index ["label"], name: "index_custom_attributes_on_label", unique: true
  end

  create_table "custom_attributes_sub_categories", id: false, force: :cascade do |t|
    t.bigint "sub_category_id", null: false
    t.bigint "custom_attribute_id", null: false
    t.index ["custom_attribute_id"], name: "index_custom_attributes_sub_categories_on_custom_attribute_id"
    t.index ["sub_category_id", "custom_attribute_id"], name: "idx_on_sub_category_id_custom_attribute_id_b00c6955d4", unique: true
    t.index ["sub_category_id"], name: "index_custom_attributes_sub_categories_on_sub_category_id"
  end

  create_table "custom_products", force: :cascade do |t|
    t.citext "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "highlighted_image_id"
    t.index ["user_id", "name"], name: "index_custom_products_on_user_id_and_name", unique: true
  end

  create_table "custom_products_sub_categories", id: false, force: :cascade do |t|
    t.bigint "custom_product_id", null: false
    t.bigint "sub_category_id", null: false
    t.index ["custom_product_id", "sub_category_id"], name: "idx_on_custom_product_id_sub_category_id_7b23a66fa1", unique: true
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.bigint "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "newsletters", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "notes", force: :cascade do |t|
    t.text "text", null: false
    t.bigint "product_id", null: false
    t.bigint "product_variant_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["product_id"], name: "index_notes_product_id"
    t.index ["product_variant_id"], name: "index_notes_product_variant_id"
    t.index ["user_id", "product_id", "product_variant_id"], name: "index_notes_on_user_id_and_product_id_and_product_variant_id", unique: true
  end

  create_table "pg_search_documents", force: :cascade do |t|
    t.text "content"
    t.string "searchable_type"
    t.bigint "searchable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["searchable_type", "searchable_id"], name: "index_pg_search_documents_on_searchable"
  end

  create_table "possessions", force: :cascade do |t|
    t.bigint "product_id"
    t.bigint "user_id", null: false
    t.bigint "product_variant_id"
    t.datetime "created_at"
    t.bigint "custom_product_id"
    t.boolean "prev_owned", default: false, null: false
    t.datetime "period_from"
    t.datetime "period_to"
    t.bigint "product_option_id"
    t.bigint "highlighted_image_id"
    t.decimal "price_purchase", precision: 12, scale: 4
    t.string "price_purchase_currency"
    t.decimal "price_sale", precision: 12, scale: 4
    t.string "price_sale_currency"
    t.index ["product_id", "product_variant_id", "user_id"], name: "idx_on_product_id_product_variant_id_user_id_bdd46f0681"
    t.index ["product_variant_id"], name: "index_possessions_product_variant_id"
    t.index ["user_id"], name: "index_possessions_user_id"
  end

  create_table "product_options", force: :cascade do |t|
    t.citext "option", null: false
    t.bigint "product_id"
    t.bigint "product_variant_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "model_no"
    t.index ["model_no", "product_id"], name: "index_product_options_on_model_no_and_product_id", unique: true, where: "(model_no IS NOT NULL)"
    t.index ["model_no", "product_variant_id"], name: "index_product_options_on_model_no_and_product_variant_id", unique: true, where: "(model_no IS NOT NULL)"
    t.index ["option", "product_id"], name: "index_product_options_on_option_and_product_id", unique: true
    t.index ["option", "product_variant_id"], name: "index_product_options_on_option_and_product_variant_id", unique: true
    t.index ["product_id"], name: "index_product_options_product_id"
    t.index ["product_variant_id"], name: "index_product_options_product_variant_id"
  end

  create_table "product_variants", force: :cascade do |t|
    t.citext "name", default: ""
    t.text "description"
    t.integer "release_year"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "product_id", null: false
    t.integer "release_day"
    t.integer "release_month"
    t.decimal "price", precision: 12, scale: 4
    t.string "price_currency"
    t.string "slug", null: false
    t.boolean "discontinued", null: false
    t.integer "discontinued_day"
    t.integer "discontinued_month"
    t.integer "discontinued_year"
    t.boolean "diy_kit", default: false, null: false
    t.string "model_no"
    t.index ["name", "product_id", "model_no", "release_day", "release_month", "release_year"], name: "idx_on_name_product_id_model_no_release_day_release_7d3b57d931", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.citext "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "brand_id", null: false
    t.boolean "discontinued", default: false, null: false
    t.string "slug", null: false
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
    t.boolean "diy_kit", default: false, null: false
    t.string "model_no"
    t.index "\"left\"((name)::text, 1)", name: "index_products_name_prefix"
    t.index ["brand_id"], name: "index_products_on_brand_id"
    t.index ["custom_attributes"], name: "index_products_on_custom_attributes", using: :gin
    t.index ["discontinued"], name: "index_products_on_discontinued"
    t.index ["diy_kit"], name: "index_products_on_diy_kit"
    t.index ["model_no", "brand_id"], name: "index_products_on_model_no_and_brand_id", unique: true
    t.index ["name"], name: "gin_index_products_on_name", opclass: :gin_trgm_ops, using: :gin
    t.index ["name"], name: "index_products_on_name"
    t.index ["release_day"], name: "index_products_on_release_day"
    t.index ["release_month"], name: "index_products_on_release_month"
    t.index ["release_year"], name: "index_products_on_release_year"
    t.index ["slug"], name: "index_products_on_slug"
  end

  create_table "products_sub_categories", id: false, force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "sub_category_id", null: false
    t.index ["product_id", "sub_category_id"], name: "idx_on_product_id_sub_category_id_b7601e15e2", unique: true
    t.index ["product_id"], name: "index_products_sub_categories_on_product_id"
    t.index ["sub_category_id"], name: "index_products_sub_categories_on_sub_category_id"
  end

  create_table "setup_possessions", force: :cascade do |t|
    t.bigint "setup_id", null: false
    t.bigint "possession_id", null: false
    t.index ["possession_id"], name: "index_setup_possessions_on_possession_id", unique: true
    t.index ["setup_id"], name: "index_setup_possessions_on_setup_id"
  end

  create_table "setups", force: :cascade do |t|
    t.citext "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.boolean "private", null: false
    t.index ["name", "user_id"], name: "index_setups_on_name_and_user_id", unique: true
    t.index ["user_id"], name: "index_setups_on_user_id"
  end

  create_table "sub_categories", force: :cascade do |t|
    t.citext "name", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.citext "slug", null: false
    t.integer "order"
    t.index ["category_id", "name"], name: "index_sub_categories_category_id_name", unique: true
    t.index ["category_id", "slug"], name: "index_sub_categories_category_id_slug", unique: true
  end

  create_table "user_agents", force: :cascade do |t|
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.boolean "receives_newsletter", default: true
    t.index "lower((email)::text)", name: "index_users_on_email", unique: true
    t.index "lower((user_name)::text)", name: "index_users_on_user_name", unique: true
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["user_name"], name: "index_users_user_name", unique: true
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
  add_foreign_key "bookmark_lists", "users"
  add_foreign_key "bookmarks", "product_variants"
  add_foreign_key "bookmarks", "products"
  add_foreign_key "bookmarks", "users"
  add_foreign_key "custom_products", "users"
  add_foreign_key "notes", "product_variants"
  add_foreign_key "notes", "products"
  add_foreign_key "notes", "users"
  add_foreign_key "possessions", "custom_products"
  add_foreign_key "possessions", "product_options"
  add_foreign_key "possessions", "product_variants"
  add_foreign_key "possessions", "products"
  add_foreign_key "possessions", "users"
  add_foreign_key "product_options", "product_variants"
  add_foreign_key "product_options", "products"
  add_foreign_key "product_variants", "products"
  add_foreign_key "products", "brands"
  add_foreign_key "setup_possessions", "possessions"
  add_foreign_key "setup_possessions", "setups"
  add_foreign_key "setups", "users"
  add_foreign_key "sub_categories", "categories"

  create_view "product_items", sql_definition: <<-SQL
      SELECT products.id,
      products.name,
      products.description,
      products.discontinued,
      products.slug AS product_slug,
      products.release_day,
      products.release_month,
      products.release_year,
      products.price,
      products.price_currency,
      products.discontinued_year,
      products.discontinued_month,
      products.discontinued_day,
      products.diy_kit,
      products.model_no,
      products.custom_attributes,
      products.brand_id,
      'Product'::text AS item_type,
      products.id AS product_id,
      NULL::citext AS variant_name,
      NULL::text AS variant_description,
      NULL::character varying AS variant_slug,
      array_agg(DISTINCT sub_categories.name) AS sub_category_names
     FROM ((products
       LEFT JOIN products_sub_categories psc ON ((psc.product_id = products.id)))
       LEFT JOIN sub_categories ON ((sub_categories.id = psc.sub_category_id)))
    GROUP BY products.id, products.name, products.description, products.discontinued, products.slug, products.release_day, products.release_month, products.release_year, products.price, products.price_currency, products.discontinued_year, products.discontinued_month, products.discontinued_day, products.diy_kit, products.model_no, products.custom_attributes, products.brand_id
  UNION ALL
   SELECT product_variants.id,
      products.name,
      products.description,
      product_variants.discontinued,
      products.slug AS product_slug,
      product_variants.release_day,
      product_variants.release_month,
      product_variants.release_year,
      product_variants.price,
      product_variants.price_currency,
      product_variants.discontinued_year,
      product_variants.discontinued_month,
      product_variants.discontinued_day,
      product_variants.diy_kit,
      product_variants.model_no,
      products.custom_attributes,
      products.brand_id,
      'ProductVariant'::text AS item_type,
      product_variants.product_id,
      product_variants.name AS variant_name,
      product_variants.description AS variant_description,
      product_variants.slug AS variant_slug,
      array_agg(DISTINCT sub_categories.name) AS sub_category_names
     FROM (((product_variants
       JOIN products ON ((product_variants.product_id = products.id)))
       LEFT JOIN products_sub_categories psc ON ((psc.product_id = products.id)))
       LEFT JOIN sub_categories ON ((sub_categories.id = psc.sub_category_id)))
    GROUP BY product_variants.id, products.name, products.description, product_variants.discontinued, products.slug, product_variants.release_day, product_variants.release_month, product_variants.release_year, product_variants.price, product_variants.price_currency, product_variants.discontinued_year, product_variants.discontinued_month, product_variants.discontinued_day, product_variants.diy_kit, product_variants.model_no, products.custom_attributes, products.brand_id, product_variants.product_id, product_variants.name, product_variants.description, product_variants.slug;
  SQL
end
