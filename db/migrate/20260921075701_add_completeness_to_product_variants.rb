# frozen_string_literal: true

# A variant's completeness depends only on its own columns -- description, release_year,
# discontinued(_year) -- same reasoning as AddCompletenessToBrands: a generated column recomputes
# on write regardless, so this can never go stale and needs no recompute path.
#
# The weights must stay in step with ProductVariant::COMPLETENESS_WEIGHTS and
# ProductVariant#completeness_score. CompletenessScoreTest asserts the two agree for every
# fixture row.
class AddCompletenessToProductVariants < ActiveRecord::Migration[8.1]
  COMPLETENESS_SQL = <<~SQL.squish
    (ROUND(
      100.0 * (
          CASE WHEN NULLIF(BTRIM(description), '') IS NOT NULL THEN 3 ELSE 0 END
        + CASE WHEN release_year IS NOT NULL THEN 2 ELSE 0 END
        + CASE WHEN discontinued IS TRUE AND discontinued_year IS NOT NULL THEN 1 ELSE 0 END
      ) / (5 + CASE WHEN discontinued IS TRUE THEN 1 ELSE 0 END)
    ))::integer
  SQL

  def change
    add_column :product_variants, :completeness, :virtual, type: :integer, as: COMPLETENESS_SQL,
                                                           stored: true
    add_index :product_variants, :completeness
  end
end
