# frozen_string_literal: true

# rubocop:disable Style/ClassAndModuleChildren, Rails/ApplicationRecord
module PaperTrail
  class Version < ActiveRecord::Base
    # rubocop:enable Style/ClassAndModuleChildren, Rails/ApplicationRecord

    include PaperTrail::VersionConcern

    # whodunnit holds the user ID as a string. The preloader casts the values to the type of
    # users.id, so the admin pages can preload the users of a full page with one query.
    belongs_to :whodunnit_user, class_name: 'User', foreign_key: :whodunnit, optional: true, inverse_of: false

    # simplecov:disable
    def self.ransackable_attributes(_auth_object = nil)
      %w[
        comment
        created_at
        event
        id
        id_value
        item_id
        item_type
        object
        object_changes
        whodunnit
      ]
    end

    def self.ransackable_associations(_auth_object = nil)
      %w[]
    end
    # simplecov:enable
  end
end
