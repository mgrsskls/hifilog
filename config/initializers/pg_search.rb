# frozen_string_literal: true

# pg_search's `ignoring: :accents` (used by PgSearchByName, the only place pg_search_scope is
# defined in this app) only strips diacritics before indexing/matching text. Names containing
# other punctuation, e.g. "T.L.A.", still fail to match a search for "TLA": to_tsvector keeps
# "t.l.a" as one token, distinct from "tla", and the trigram similarity between "tla" and
# "t.l.a." falls below PgSearchByName's 0.2 threshold.
#
# pg_search has no built-in option for this, so this extends the same normalization pipeline it
# already uses for accents -- PgSearch::Normalizer#add_normalization, applied identically to both
# the indexed document and the incoming query by every tsearch/trigram feature -- to also drop
# any character that isn't a letter, digit, or whitespace. Since every pg_search_scope in this
# app goes through PgSearchByName, this applies everywhere search is used.
#
# Uses RelevanceOrdering::STRIP_PATTERN rather than its own copy of the pattern: that module
# reimplements this same normalization in raw SQL (to compute relevance tiers outside of
# pg_search's own ranking), and the two drifting out of sync would silently break the tier
# computation for any name pg_search matches but the tier SQL doesn't (or vice versa).
class PgSearch::Normalizer
  prepend(Module.new do
    def add_normalization(sql_expression)
      normalized = super

      sql_node = normalized.is_a?(Arel::Nodes::Node) ? normalized : Arel.sql(normalized)

      Arel::Nodes::NamedFunction.new(
        'regexp_replace',
        [
          sql_node,
          Arel::Nodes.build_quoted(RelevanceOrdering::STRIP_PATTERN),
          Arel::Nodes.build_quoted(''),
          Arel::Nodes.build_quoted('g')
        ]
      ).to_sql
    end
  end)
end
