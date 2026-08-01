# frozen_string_literal: true

# Which sub-categories a brand belongs to is now part of its completeness: it drives the category
# filters, the generated fallback description and the meta description, so it is weighted 3 —
# level with `description`. The denominator goes 14 -> 17.
#
# The categories live in a join table, and a stored generated column may only read its own row.
# So a counter cache column comes first (mirroring products_count) and the expression reads that.
# Brand keeps it in step; the backfill below covers every row written before it existed.
#
# Postgres cannot alter a generated column's expression before 17, so the column is dropped and
# re-added. There is nothing to lose: the value is derived, not stored input.
#
# The weights must stay in step with Brand::COMPLETENESS_WEIGHTS and Brand#completeness_fields.
# CompletenessScoreTest asserts the two agree.
class AddSubCategoriesCountToBrands < ActiveRecord::Migration[8.1]
  NEW_SQL = <<~SQL.squish
    (ROUND(
      100.0 * (
          CASE WHEN products_count > 0 THEN 5 ELSE 0 END
        + CASE WHEN NULLIF(BTRIM(description), '') IS NOT NULL THEN 3 ELSE 0 END
        + CASE WHEN sub_categories_count > 0 THEN 3 ELSE 0 END
        + CASE WHEN NULLIF(BTRIM(country_code), '') IS NOT NULL THEN 2 ELSE 0 END
        + CASE WHEN discontinued IS NOT NULL THEN 2 ELSE 0 END
        + CASE WHEN founded_year IS NOT NULL THEN 1 ELSE 0 END
        + CASE
            WHEN discontinued IS TRUE
              THEN CASE WHEN discontinued_year IS NOT NULL THEN 1 ELSE 0 END
            WHEN NULLIF(BTRIM(website), '') IS NOT NULL THEN 1
            ELSE 0
          END
      ) / 17
    ))::integer
  SQL

  OLD_SQL = <<~SQL.squish
    (ROUND(
      100.0 * (
          CASE WHEN products_count > 0 THEN 5 ELSE 0 END
        + CASE WHEN NULLIF(BTRIM(description), '') IS NOT NULL THEN 3 ELSE 0 END
        + CASE WHEN NULLIF(BTRIM(country_code), '') IS NOT NULL THEN 2 ELSE 0 END
        + CASE WHEN discontinued IS NOT NULL THEN 2 ELSE 0 END
        + CASE WHEN founded_year IS NOT NULL THEN 1 ELSE 0 END
        + CASE
            WHEN discontinued IS TRUE
              THEN CASE WHEN discontinued_year IS NOT NULL THEN 1 ELSE 0 END
            WHEN NULLIF(BTRIM(website), '') IS NOT NULL THEN 1
            ELSE 0
          END
      ) / 14
    ))::integer
  SQL

  def up
    add_column :brands, :sub_categories_count, :integer, default: 0, null: false
    backfill_sub_categories_count
    replace_completeness_with(NEW_SQL)
  end

  def down
    replace_completeness_with(OLD_SQL)
    remove_column :brands, :sub_categories_count
  end

  private

  def backfill_sub_categories_count
    execute <<~SQL.squish
      UPDATE brands
      SET sub_categories_count = COALESCE((
        SELECT COUNT(*) FROM brands_sub_categories
        WHERE brands_sub_categories.brand_id = brands.id
      ), 0)
    SQL
  end

  # The generated column has to be dropped before the column it reads can go, so `down` replaces
  # the expression first. Re-adding restores the index the drop took with it.
  def replace_completeness_with(expression)
    remove_column :brands, :completeness
    add_column :brands, :completeness, :virtual, type: :integer, as: expression, stored: true
    add_index :brands, :completeness
  end
end
