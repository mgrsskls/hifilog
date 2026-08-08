# frozen_string_literal: true

# Shared behaviour for signed-token, one-click email unsubscribe endpoints
# (newsletter, follow notifications). These are public: the recipient is
# identified solely by the signed token in +hash+, so no session is required.
#
# GET renders a confirmation page without mutating anything; POST performs the
# unsubscribe. POST supports RFC 8058 one-click unsubscribe (a +List-Unsubscribe:
# One-Click+ body param) by answering with a bare status instead of a redirect.
#
# Including controllers configure the flow by overriding the four private
# methods below (+unsubscribe_service+, +unsubscribe_attribute+,
# +success_message+, +invalid_message+).
module TokenUnsubscribe
  extend ActiveSupport::Concern

  included do
    # Token-authenticated, so there is no session or CSRF token to verify, and
    # the request legitimately originates from an email client.
    skip_before_action :verify_authenticity_token, only: [:show, :create]
    # The token travels in the URL, so keep it out of the Referer header.
    before_action :set_no_referrer_policy
  end

  # GET — confirmation page. Never mutates.
  def show
    @unsubscribe_hash = params[:hash]
    @user = unsubscribe_user
  end

  # POST — perform the unsubscribe.
  def create
    @unsubscribe_hash = params[:hash]
    user = unsubscribe_user

    if user
      user.update(unsubscribe_attribute => false)
      respond_to_unsubscribe(:success)
    else
      respond_to_unsubscribe(:invalid)
    end
  end

  private

  def set_no_referrer_policy
    response.set_header('Referrer-Policy', 'no-referrer')
  end

  def unsubscribe_user
    hash_param = params[:hash].presence || request.query_parameters['hash'].presence
    unsubscribe_service.decode_token(hash_param)
  end

  def respond_to_unsubscribe(result)
    if one_click_unsubscribe_request?
      return head :bad_request if result == :invalid

      head :ok
    elsif result == :success
      redirect_to root_path, notice: success_message
    else
      redirect_to root_path, alert: invalid_message
    end
  end

  def one_click_unsubscribe_request?
    params['List-Unsubscribe'] == 'One-Click'
  end

  # --- Configuration hooks (override in including controllers) ---

  def unsubscribe_service
    raise NotImplementedError
  end

  def unsubscribe_attribute
    raise NotImplementedError
  end

  def success_message
    raise NotImplementedError
  end

  def invalid_message
    raise NotImplementedError
  end
end
