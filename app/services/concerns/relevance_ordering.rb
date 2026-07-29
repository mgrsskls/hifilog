# frozen_string_literal: true

# Coarse relevance tiers for the name searches on brands#index and
# product_items#index.
#
# pg_search *appends* its `ORDER BY <rank_alias>.rank DESC` instead of replacing
# the scope's order, so whichever sort was applied first silently won. Both
# filter services now build the whole ORDER BY themselves and finish with
# `reorder`, in this shape:
#
#   <relevance tier>, <hand-picked sort>, <primary key>
#
# Relevance beats the hand-picked sort; the hand-picked sort orders rows *inside*
# a tier; the primary key keeps pagination stable.
#
# The tiers are deliberately coarse. A raw rank is near-unique per row, so using
# it directly would leave the hand-picked sort with nothing left to order.
module RelevanceOrdering
  extend ActiveSupport::Concern

  TIER_EXACT = 0
  TIER_PREFIX = 1
  TIER_CONTAINS = 2
  TIER_FUZZY = 3

  private

  # `exact`    – SQL expressions tested for equality (tier 0) and prefix (tier 1);
  #              a row qualifies as soon as one of them matches.
  # `contains` – expressions concatenated into a single haystack for the
  #              substring test (tier 2).
  #
  # Everything else pg_search let through (tsearch prefix / trigram) is tier 3.
  # Returns nil when there is no query, so callers can skip the whole thing.
  def relevance_tier_sql(query, exact:, contains:)
    needle = query.to_s.strip
    return nil if needle.blank?

    haystack = contains.map { |expression| "COALESCE(#{expression}, '')" }.join(" || ' ' || ")
    equals = exact.map { |expression| "#{normalized_sql(expression)} = LOWER(unaccent(:exact))" }
    prefixes = exact.map { |expression| "#{normalized_sql(expression)} LIKE LOWER(unaccent(:prefix))" }

    ActiveRecord::Base.sanitize_sql_array(
      [
        <<~SQL.squish,
          CASE
            WHEN #{equals.join(' OR ')} THEN #{TIER_EXACT}
            WHEN #{prefixes.join(' OR ')} THEN #{TIER_PREFIX}
            WHEN #{normalized_sql(haystack)} LIKE LOWER(unaccent(:contains)) THEN #{TIER_CONTAINS}
            ELSE #{TIER_FUZZY}
          END
        SQL
        {
          exact: needle,
          prefix: "#{escape_like(needle)}%",
          contains: "%#{escape_like(needle)}%"
        }
      ]
    )
  end

  # `name` columns are citext; cast so LOWER/LIKE behave the same way they do in
  # the rest of the ordering SQL, and COALESCE so a NULL part of a concatenated
  # expression does not swallow the whole comparison.
  def normalized_sql(expression)
    "LOWER(unaccent(COALESCE((#{expression})::text, '')))"
  end

  def escape_like(value)
    value.gsub(/[\\%_]/) { |char| "\\#{char}" }
  end
end
