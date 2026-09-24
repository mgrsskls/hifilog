# frozen_string_literal: true

# Makes one readable sentence from a UserActivity row for ActiveAdmin, for example
# "anna added Rega Planar 3 to the collection" or "tom started following anna".
#
# Call .preload with the rows of one page before you make the sentences. It loads the users,
# the subjects and the products of the subjects with a fixed number of queries. Without it,
# each row does its own queries.
#
# When a subject does not exist anymore, the sentence uses the names in the metadata of the row.
class AdminUserActivityPresenter
  POSSESSION_ASSOCIATIONS = [
    :custom_product,
    { product: :brand },
    { product_variant: { product: :brand } }
  ].freeze

  # Setup rows keep the ID of the product in one of these metadata keys, most specific first.
  SETUP_ITEM_PATHS = {
    'custom_product_id' => :admin_custom_product_path,
    'product_variant_id' => :admin_product_variant_path,
    'product_id' => :admin_product_path
  }.freeze

  def self.preload(activities)
    activities = activities.to_a
    preload_associations(activities, [:user, :subject])

    subjects = activities.filter_map(&:subject)
    preload_associations(subjects.grep(Possession), POSSESSION_ASSOCIATIONS)
    preload_associations(subjects.grep(EventAttendee), :event)
    preload_associations(subjects.grep(UserFollow), :follower)
    activities
  end

  def self.preload_associations(records, associations)
    return if records.empty?

    ActiveRecord::Associations::Preloader.new(records:, associations:).call
  end
  private_class_method :preload_associations

  def initialize(activity, view)
    @activity = activity
    @view = view
  end

  def sentence
    case @activity.verb
    when 'added_to_collection'
      join(actor, 'added', possession_item, 'to their collection')
    when 'added_to_previous'
      join(actor, 'added', possession_item, 'to their previous products', ownership_period)
    when 'moved_to_previous'
      join(actor, 'moved', possession_item, 'to their previous products', ownership_period)
    when 'possession_image_uploaded'
      join(actor, 'uploaded an image of', possession_item)
    when 'possession_image_deleted'
      join(actor, 'deleted an image of', possession_item)
    when 'custom_product_created'
      join(actor, 'created the custom product', custom_product)
    when 'setup_created'
      join(actor, 'created the setup', setup)
    when 'setup_made_public'
      join(actor, 'made the setup', setup, 'public')
    when 'setup_made_private'
      join(actor, 'made the setup', setup, 'private')
    when 'setup_product_added'
      join(actor, 'added', setup_item, 'to the setup', setup)
    when 'setup_product_removed'
      join(actor, 'removed', setup_item, 'from the setup', setup)
    when 'event_attendance'
      join(actor, 'will attend', event, event_dates)
    when 'event_attendance_cancelled'
      join(actor, 'cancelled the attendance at', event, event_dates)
    when 'avatar_uploaded'
      join(actor, 'uploaded a new avatar')
    when 'avatar_deleted'
      join(actor, 'deleted their avatar')
    when 'followed_by_user'
      # The row belongs to the followed user. The follower is the one who did something.
      join(follower, 'started following', actor)
    else
      join(actor, @activity.verb.humanize(capitalize: false))
    end
  end

  private

  def metadata
    @activity.metadata || {}
  end

  def subject
    @activity.subject
  end

  def actor
    user_link(@activity.user)
  end

  def follower
    user = subject.is_a?(UserFollow) ? subject.follower : nil
    return user_link(user) if user

    id = metadata['follower_id']
    name = metadata['follower_user_name'].presence || 'a deleted user'
    id ? link(name, @view.admin_user_path(id)) : missing(name)
  end

  def user_link(user)
    return missing('a deleted user') unless user

    link(user.user_name, @view.admin_user_path(user))
  end

  def possession_item
    target = possession_target(subject) if subject.is_a?(Possession)
    return link(*target) if target

    missing(metadata['display_name'].presence || 'a deleted product')
  end

  # Returns the name and the admin path of the product of a possession, or nil when it has none.
  def possession_target(possession)
    if (custom_product = possession.custom_product)
      [custom_product.name, @view.admin_custom_product_path(custom_product)]
    elsif (variant = possession.product_variant)
      [variant.display_name, @view.admin_product_variant_path(variant)]
    elsif (product = possession.product)
      [product.display_name, @view.admin_product_path(product)]
    end
  end

  # Setup rows keep the IDs and the name of the product in the metadata, so no query is necessary.
  def setup_item
    name = metadata['product_display_name'].presence || 'a product'
    key, path_helper = SETUP_ITEM_PATHS.find { |metadata_key, _| metadata[metadata_key] }
    return missing(name) unless key

    link(name, @view.public_send(path_helper, metadata[key]))
  end

  def custom_product
    return link(subject.name, @view.admin_custom_product_path(subject)) if subject.is_a?(CustomProduct)

    missing(metadata['display_name'].presence || 'a deleted custom product')
  end

  def setup
    return link(subject.name, @view.admin_setup_path(subject)) if subject.is_a?(Setup)

    name = metadata['display_name'].presence || 'a deleted setup'
    id = metadata['setup_id']
    id ? link(name, @view.admin_setup_path(id)) : missing(name)
  end

  def event
    record = subject.is_a?(EventAttendee) ? subject.event : subject
    return link(record.name, @view.admin_event_path(record)) if record.is_a?(Event)

    missing(metadata['display_name'].presence || 'a deleted event')
  end

  def event_dates
    dates = [metadata['event_start_date'], metadata['event_end_date']].compact.uniq.map { |date| format_date(date) }
    return if dates.empty?

    @view.tag.small("(#{dates.join(' – ')})")
  end

  def ownership_period
    from = format_date(metadata['period_from'])
    to = format_date(metadata['period_to'])
    return if from.nil? && to.nil?

    @view.tag.small("(owned #{from || '?'} – #{to || '?'})")
  end

  def format_date(value)
    return if value.blank?

    Date.iso8601(value.to_s).strftime('%d.%m.%Y')
  rescue Date::Error
    value.to_s
  end

  def link(text, path)
    @view.link_to(text, path)
  end

  def missing(text)
    @view.tag.em(text)
  end

  def join(*parts)
    @view.safe_join(parts.compact, ' ')
  end
end
