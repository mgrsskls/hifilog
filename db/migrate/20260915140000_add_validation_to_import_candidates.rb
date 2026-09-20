# frozen_string_literal: true

# Who checked a candidate's categories, and when.
#
# A sub category on a candidate can come from three places, and they are not
# equally trustworthy: a mapping written by hand, a classifier reading the
# product name, or a second reading that checked the first. The review needs to
# see which -- an unchecked proposal deserves a careful look, a checked one
# deserves a glance.
#
# `validated_by` holds what did the checking ("claude-opus-5", an admin's
# email), not a boolean, so that a later check by something else is
# distinguishable rather than overwriting the first silently.
class AddValidationToImportCandidates < ActiveRecord::Migration[8.1]
  def change
    add_column :import_candidates, :validated_at, :datetime
    add_column :import_candidates, :validated_by, :string
    add_column :import_candidates, :validation_note, :text

    # The review queue asks for "not checked yet" as its first filter.
    add_index :import_candidates, %i[status validated_at]
  end
end
