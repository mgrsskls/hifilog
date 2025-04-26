PgSearch.multisearch_options = {
  ignoring: :accents,
  using: {
    tsearch: {
      any_word: true,
      prefix: true,
      highlight: {
        StartSel: '<mark>',
				StopSel: '</mark>',
				MaxFragments: 3,
				FragmentDelimiter: ' […] '
      }
    },
    trigram: {
      threshold: 0.3
    },
  },
  ranked_by: ':trigram'
}
