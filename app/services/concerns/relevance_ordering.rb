# frozen_string_literal: true

# Coarse relevance tiers for the name searches on brands#index, product_items#index,
# and the global search.
#
# pg_search *appends* its `ORDER BY <rank_alias>.rank DESC` instead of replacing
# the scope's order, so whichever sort was applied first silently won. Both
# filter services now build the whole ORDER BY themselves and finish with
# `reorder`, in this shape:
#
#   <relevance tier>, <closeness DESC>, <hand-picked sort>, <primary key>
#
# Relevance beats closeness beats the hand-picked sort; the hand-picked sort only
# breaks ties between equally-close rows; the primary key keeps pagination stable.
#
# The tiers are deliberately coarse (see TIER_FUZZY below), so `closeness` -- pg_trgm's
# own similarity score, on the same normalized text the tier comparisons use -- orders
# rows *inside* a tier by how close they actually are, instead of alphabetically.
# Without it, a query that never reaches tier 0-2 (e.g. no spaces where the stored name
# has them) buries its best fuzzy match under whatever the alphabet puts first.
#
# This is a known-imperfect heuristic, not a true multi-word coverage score: a short
# document (e.g. a bare brand name) can still out-rank a longer one that actually
# matches more of a multi-word query, because similarity() penalizes total string
# length on both sides. word_similarity() was tried as a fix and made things worse --
# it let coincidental substring alignments in unrelated longer rows outscore genuine
# matches -- so this stays as plain similarity() until a real per-word scoring pass
# is worth the added complexity.
module RelevanceOrdering
  extend ActiveSupport::Concern

  TIER_EXACT = 0
  TIER_PREFIX = 1
  TIER_CONTAINS = 2
  TIER_FUZZY = 3

  # Punctuation stripped from both sides of every comparison this module builds, and
  # (via config/initializers/pg_search.rb, which references this same constant) from
  # everything pg_search itself indexes and matches against. One shared pattern so the
  # two normalizers can't drift apart -- valid as both a Ruby Regexp source and a
  # Postgres regexp_replace pattern, since POSIX bracket-expression syntax is the same
  # in both.
  STRIP_PATTERN = '[^[:alnum:][:space:]]'

  private

  # `exact`    – SQL expressions tested for equality (tier 0) and prefix (tier 1);
  #              a row qualifies as soon as one of them matches.
  # `contains` – expressions concatenated into a single haystack, used both for the
  #              substring test (tier 2) and for the closeness score that breaks ties
  #              within a tier (see the module doc above).
  #
  # Everything else pg_search let through (tsearch prefix / trigram) is tier 3.
  # Returns nil when there is no query, so callers can skip the whole thing.
  def relevance_tier_sql(query, exact:, contains:)
    needle = strip_special_characters(query)
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
          END, similarity(#{normalized_sql(haystack)}, LOWER(unaccent(:exact))) DESC
        SQL
        {
          exact: needle,
          prefix: "#{needle}%",
          contains: "%#{needle}%",
          strip_pattern: STRIP_PATTERN
        }
      ]
    )
  end

  # `name` columns are citext; cast so LOWER/LIKE behave the same way they do in
  # the rest of the ordering SQL, and COALESCE so a NULL part of a concatenated
  # expression does not swallow the whole comparison. Punctuation is stripped with
  # the same STRIP_PATTERN the pg_search normalizer strips it with (see
  # config/initializers/pg_search.rb) so a name like "T.L.A." still lands in the
  # exact/prefix tier for a "TLA" query.
  #
  # STRIP_PATTERN is passed as a bind value rather than spliced into the SQL text
  # directly: sanitize_sql_array treats any `:word` in the SQL *string* as a named
  # bind variable, so a literal `[:alnum:]` in the template would be misread as a
  # placeholder named `:alnum`. Passing it as the `:strip_pattern` value sidesteps
  # that -- only the template is scanned for placeholders, not the substituted values.
  def normalized_sql(expression)
    "REGEXP_REPLACE(LOWER(unaccent(COALESCE((#{expression})::text, ''))), :strip_pattern, '', 'g')"
  end

  # needle is already restricted to STRIP_PATTERN's allowed characters (letters,
  # digits, whitespace), so it can never contain a LIKE metacharacter (%, _, \) that
  # would need escaping here.
  def strip_special_characters(value)
    value.to_s.gsub(Regexp.new(STRIP_PATTERN), '').strip
  end
end
