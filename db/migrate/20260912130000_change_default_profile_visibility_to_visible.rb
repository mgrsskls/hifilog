# frozen_string_literal: true

# New accounts are public by default.
#
# The column default was 0 (`hidden`), which made every new profile invisible unless the user
# found the setting in Settings → Profile. That works against a community database: contributions
# and collections are the point, and an opt-out default serves discoverability better than an
# opt-in one. Signup now exposes the choice explicitly (users/registrations/new), so the default
# is visible rather than silent.
#
# Existing rows are deliberately left untouched: a stored 0 cannot be distinguished from a
# deliberate "hidden" choice, so backfilling would expose profiles their owners chose to hide.
class ChangeDefaultProfileVisibilityToVisible < ActiveRecord::Migration[8.1]
  def up
    change_column_default :users, :profile_visibility, from: 0, to: 2
  end

  def down
    change_column_default :users, :profile_visibility, from: 2, to: 0
  end
end
