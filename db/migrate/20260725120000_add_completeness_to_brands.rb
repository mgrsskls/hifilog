# frozen_string_literal: true

# A brand's completeness depends only on its own columns — including products_count, which the
# counter cache maintains with a raw UPDATE that skips model callbacks. A generated column
# recomputes on write regardless, so this can never go stale and needs no recompute path, which
# matters because there is no background job runner configured.
#
# The weights must stay in step with Brand::COMPLETENESS_WEIGHTS and Brand#completeness_score.
# CompletenessScoreTest asserts the two agree for every fixture row.
class AddCompletenessToBrands < ActiveRecord::Migration[8.1]
  COMPLETENESS_SQL = <<~SQL.squish
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

  def change
    add_column :brands, :completeness, :virtual, type: :integer, as: COMPLETENESS_SQL, stored: true
    add_index :brands, :completeness
  end
end
