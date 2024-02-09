# rubocop:disable Style/ClassAndModuleChildren, Rails/ApplicationRecord
module PaperTrail
  class Version < ActiveRecord::Base
    # rubocop:enable Style/ClassAndModuleChildren, Rails/ApplicationRecord

    def self.ransackable_attributes(_auth_object = nil)
      %w[
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
  end
end
