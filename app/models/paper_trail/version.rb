# rubocop:disable Style/ClassAndModuleChildren, Rails/ApplicationRecord
module PaperTrail
  class Version < ActiveRecord::Base
    # rubocop:enable Style/ClassAndModuleChildren, Rails/ApplicationRecord

    include PaperTrail::VersionConcern

    # :nocov:
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
    # :nocov:
  end
end
