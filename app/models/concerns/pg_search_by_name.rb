# frozen_string_literal: true

module PgSearchByName
  extend ActiveSupport::Concern

  class_methods do
    def pg_search_by_name(extra_options = {})
      base_options = {
        ignoring: :accents,
        using: {
          tsearch: { any_word: false, prefix: true },
          trigram: { threshold: 0.2 }
        },
        ranked_by: ':trigram'
      }

      pg_search_scope :search_by_name, **base_options, **extra_options
    end
  end
end
