# frozen_string_literal: true

# Shared slug patterns for FriendlyId models and config/routes.rb constraints.
#
# SLUG_PATH_CONSTRAINT has no \A/\z anchors — Rails route constraints forbid them.
# SLUG_ROUTE_PATTERN is for validating a full param value in controllers.
module SlugRouteConstraints
  extend ActiveSupport::Concern

  included do
    # FriendlyId's :slugged module only regenerates when slug is blank; regenerate on rename too.
    def should_generate_new_friendly_id?
      slug.blank? || name_changed?
    end
  end

  SLUG_PATTERN_SOURCE = '[a-z0-9]+(?:-[a-z0-9]+)*'
  SLUG_PATH_CONSTRAINT = Regexp.new(SLUG_PATTERN_SOURCE)
  SLUG_ROUTE_PATTERN = Regexp.new("\\A#{SLUG_PATTERN_SOURCE}\\z")
end
