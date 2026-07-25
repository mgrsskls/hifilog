# frozen_string_literal: true

# A discontinued brand is asked for the year it went out of business, in the slot where a brand
# still in business is asked for a website. Both are weight 1, so the denominator stays 14 either
# way and scores remain comparable across the whole catalogue.
#
# Postgres cannot alter a generated column's expression before 17, so the column is dropped and
# re-added. There is nothing to lose: the value is derived, not stored input.
#
# The weights must stay in step with Brand::COMPLETENESS_WEIGHTS and Brand#completeness_fields.
# CompletenessScoreTest asserts the two agree.
class UpdateBrandsCompletenessForDiscontinuedYear < ActiveRecord::Migration[8.1]
  NEW_SQL = <<~SQL.squish
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

  OLD_SQL = <<~SQL.squish
    (ROUND(
      100.0 * (
          CASE WHEN products_count > 0 THEN 5 ELSE 0 END
        + CASE WHEN NULLIF(BTRIM(description), '') IS NOT NULL THEN 3 ELSE 0 END
        + CASE WHEN NULLIF(BTRIM(country_code), '') IS NOT NULL THEN 2 ELSE 0 END
        + CASE WHEN discontinued IS NOT NULL THEN 2 ELSE 0 END
        + CASE WHEN founded_year IS NOT NULL THEN 1 ELSE 0 END
        + CASE
            WHEN discontinued IS TRUE THEN 0
            WHEN NULLIF(BTRIM(website), '') IS NOT NULL THEN 1
            ELSE 0
          END
      ) / CASE WHEN discontinued IS TRUE THEN 13 ELSE 14 END
    ))::integer
  SQL

  def up
    replace_completeness_with(NEW_SQL)
  end

  def down
    replace_completeness_with(OLD_SQL)
  end

  private

  def replace_completeness_with(expression)
    remove_column :brands, :completeness
    add_column :brands, :completeness, :virtual, type: :integer, as: expression, stored: true
    add_index :brands, :completeness
  end
end
