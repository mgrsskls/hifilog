# frozen_string_literal: true

# Overrides Kaminari's ActiveRecord::Relation#total_count (used for total_pages, out_of_range?,
# etc.) with a value the caller already computed cheaply — see ProductFilterService#total_count —
# instead of Kaminari's default `SELECT COUNT(*) FROM (relation)`, which for product_items would
# needlessly scan the whole view.
module PrecomputedTotalCount
  def self.attach(relation, total)
    relation.extend(self)
    relation.instance_variable_set(:@precomputed_total_count, total)
    relation
  end

  def total_count(*)
    @precomputed_total_count
  end
end
