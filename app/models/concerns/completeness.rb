# frozen_string_literal: true

# Describes how much of a catalogue entry has actually been filled in, both as a list of named
# gaps (for the prompts on entry pages) and as a 0-100 score (for ordering the contribute queues).
#
# Most entries carry little more than a name and a brand, so "incomplete" is the normal state
# here rather than an error. Naming the specific gaps is what lets a contributor be handed a
# small, finishable job instead of a blank form.
#
# Fields are weighted by how many surfaces they feed rather than by feel: a field that only shows
# on the entry page is worth less than one that also drives filtering, search or the meta
# description. Including models declare COMPLETENESS_WEIGHTS.
#
# A field that cannot meaningfully exist for a particular record is dropped from the denominator
# rather than scored as missing — override #completeness_fields for that. Otherwise entries get
# permanently capped below 100% for something nobody can fix.
#
# IMPORTANT: the score is computed twice — here in Ruby, and in SQL so that it can be sorted on
# (a generated column on `brands`, an expression in the `contribute_product_items` view). The two
# must agree. CompletenessScoreTest compares them for every fixture row; change one and you must
# change both.
module Completeness
  extend ActiveSupport::Concern

  def completeness_fields
    self.class::COMPLETENESS_WEIGHTS.keys
  end

  # Presence test per field. Overridden where `.present?` is the wrong question — most notably a
  # nullable boolean, where false is a real answer and only nil means "nobody has said".
  def completeness_present?(field)
    public_send(field).present?
  end

  def missing_fields
    completeness_fields.reject { |field| completeness_present?(field) }
  end

  # Highlighted custom attributes are the app's own notion of a "key spec"
  # (see CustomAttribute#highlighted). Only products carry custom attribute values, so everything
  # else has none to be missing.
  def missing_highlighted_attributes
    []
  end

  # [earned, max] pairs. Models append components that are not plain field presence.
  def completeness_components
    completeness_fields.map do |field|
      weight = self.class::COMPLETENESS_WEIGHTS.fetch(field)

      [completeness_present?(field) ? weight : 0, weight]
    end
  end

  # Rational rather than Float throughout: the SQL side computes in `numeric`, and exact
  # arithmetic here keeps the two from disagreeing on a rounding boundary.
  def completeness_score
    components = completeness_components
    return 100 if components.empty?

    earned = components.sum { |points, _| points }
    max = components.sum { |_, weight| weight }
    return 100 if max.zero?

    (Rational(100) * earned / max).round
  end

  def complete?
    missing_fields.empty? && missing_highlighted_attributes.empty?
  end

  def incomplete?
    !complete?
  end
end
