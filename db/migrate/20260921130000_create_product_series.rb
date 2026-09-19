# frozen_string_literal: true

# Product series: a named product line of one brand ("Klipsch Heritage", "Fezz Evolution").
# See docs/product-series.md.
#
# The schema had an unused `product_families` table and `products.product_family_id` column
# (no model, no code). This migration replaces them. If a database still holds rows there, they
# are copied into `product_series` before the old objects are dropped, so nothing is lost. The
# product slugs of copied rows are not changed here; run `bin/rails series:resync_slugs` after
# the migration if the output says so.
class CreateProductSeries < ActiveRecord::Migration[8.1]
  def up
    create_table :product_series do |t|
      t.references :brand, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.citext :name, null: false
      t.citext :slug, null: false
      t.text :description
      # Base products only, like the series page and the brand page count them. Variants are
      # editions of a product, not new products in the line.
      t.integer :products_count, null: false, default: 0

      t.timestamps
    end

    # citext makes both case-insensitive: "Heritage" and "heritage" are the same series.
    add_index :product_series, [:brand_id, :name], unique: true
    add_index :product_series, [:brand_id, :slug], unique: true
    add_index :product_series, :name, using: :gin, opclass: :gin_trgm_ops,
                                      name: 'index_product_series_on_name_trgm'

    add_reference :products, :product_series, foreign_key: { on_delete: :nullify }, index: false

    # Series page and "More from this series" in the default order, without a sort step.
    add_index :products, [:product_series_id, :release_year, :release_month, :release_day, :id],
              name: 'index_products_on_series_and_release_date'
    # The series filter of the brand products page.
    add_index :products, [:brand_id, :product_series_id]

    copy_legacy_product_families
    drop_legacy_product_families
  end

  def down
    # series_follows and products.series_assigned_at existed in an earlier version of this
    # migration (series follows were removed before release). A database that ran that version
    # still has them, so they are removed here if they exist.
    drop_table :series_follows, if_exists: true
    remove_index :products, name: 'index_products_on_series_and_release_date'
    remove_index :products, [:brand_id, :product_series_id]
    remove_index :products, [:product_series_id, :series_assigned_at], if_exists: true
    remove_column :products, :series_assigned_at, if_exists: true
    remove_reference :products, :product_series, foreign_key: true
    drop_table :product_series

    create_table :product_families do |t|
      t.references :brand, null: false, foreign_key: true
      t.citext :name, null: false
      t.timestamps
    end
    add_index :product_families, [:brand_id, :name], unique: true
    add_reference :products, :product_family, foreign_key: { on_delete: :nullify }
  end

  private

  def copy_legacy_product_families
    return unless table_exists?(:product_families)

    families = select_all('SELECT id, brand_id, name, created_at, updated_at FROM product_families').to_a
    return if families.empty?

    say "Copying #{families.size} product families into product_series. " \
        'Run `bin/rails series:resync_slugs` afterwards.'

    families.each do |family|
      slug = unique_slug(family['brand_id'], family['name'].to_s.parameterize.presence || "series-#{family['id']}")
      series_id = select_value(<<~SQL.squish)
        INSERT INTO product_series (brand_id, name, slug, created_at, updated_at)
        VALUES (#{quote(family['brand_id'])}, #{quote(family['name'])}, #{quote(slug)},
                #{quote(family['created_at'])}, #{quote(family['updated_at'])})
        ON CONFLICT (brand_id, name) DO UPDATE SET updated_at = product_series.updated_at
        RETURNING id
      SQL

      # Only products of the same brand: a product of another brand can not have this series.
      execute(<<~SQL.squish)
        UPDATE products
        SET product_series_id = #{quote(series_id)}
        WHERE product_family_id = #{quote(family['id'])}
          AND brand_id = #{quote(family['brand_id'])}
      SQL
    end

    execute(<<~SQL.squish)
      UPDATE product_series
      SET products_count = (
        SELECT COUNT(*) FROM products WHERE products.product_series_id = product_series.id
      )
    SQL
  end

  def unique_slug(brand_id, base)
    slug = base
    index = 2
    while select_value("SELECT 1 FROM product_series WHERE brand_id = #{quote(brand_id)} AND slug = #{quote(slug)}")
      slug = "#{base}-#{index}"
      index += 1
    end
    slug
  end

  def drop_legacy_product_families
    if column_exists?(:products, :product_family_id)
      remove_foreign_key :products, :product_families, if_exists: true
      remove_index :products, :product_family_id, if_exists: true
      remove_column :products, :product_family_id
    end

    drop_table :product_families, if_exists: true
  end

  def quote(value)
    connection.quote(value)
  end
end
