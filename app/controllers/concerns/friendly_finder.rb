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
    return resource if request.path == path_helper.call(resource)

    redirect_to URI.parse(path_helper.call(resource)).path, status: :moved_permanently and return
  end
end
