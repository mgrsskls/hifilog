# frozen_string_literal: true

module ProfileVisibility
  extend ActiveSupport::Concern

  # Finds a user by user_name (case-insensitive) and raises RecordNotFound if the
  # profile isn't visible to the current viewer, so a hidden/logged-in-only profile
  # renders the same 404 as a nonexistent one rather than leaking that it exists.
  def find_viewable_user!(user_name)
    user = User.find_by('lower(user_name) = ?', user_name.to_s.downcase)
    raise ActiveRecord::RecordNotFound unless user && profile_viewable_by_current_user?(user)

    user
  end

  private

  def profile_viewable_by_current_user?(user)
    return true if current_user == user
    # An unconfirmed account cannot sign in, so it has no collection, no activity and no
    # contributions -- there is nothing to show and no owner who chose to show it. Treating it as
    # not-found keeps abandoned and automated signups off the public site.
    return false unless user.confirmed?
    return false if user.hidden?
    return false if user.logged_in_only? && !user_signed_in?

    true
  end
end
