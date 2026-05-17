# frozen_string_literal: true

module FriendlyFinder
  extend ActiveSupport::Concern

  # Finds the resource using FriendlyId; if the request path is not current,
  # it redirects to the correct friendly URL.
  #
  # resource_class - The Active Record class (e.g. Product or Brand)
  # id_param - The param key to use (default :id)
  # path_helper - A proc that takes the resource and returns the correct URL (e.g. ->(r){ product_path(r) })
  def find_resource(resource_class, id_param = :id, path_helper:)
    resource = resource_class.friendly.find(params[id_param])
    redirect_to_canonical_path(path_helper.call(resource)) { return resource }
  end

  # Finds a record in a pre-scoped relation (e.g. user.setups) and 301-redirects stale slugs.
  def find_scoped_resource(scope, id_param, path_helper:)
    resource = scope.friendly.find(params[id_param])
    redirect_to_canonical_path(path_helper.call(resource)) { return resource }
  end

  private

  def redirect_to_canonical_path(canonical_url)
    canonical_path = URI.parse(canonical_url).path
    return yield if request.path == canonical_path

    redirect_to canonical_path, status: :moved_permanently
    nil
  end
end
