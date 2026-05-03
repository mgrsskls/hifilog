# frozen_string_literal: true

require 'test_helper'

class CustomProductPossessionPresentersTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  def default_url_options
    { host: 'www.example.com', protocol: 'https' }
  end
  test 'CustomProductPossessionPresenter summarizes ownership windows for archival customs' do
    possession = possessions(:prev_custom_product)

    travel_to Time.zone.local(2026, 3, 28, 12, 0, 0) do
      possession.update!(
        prev_owned: true,
        period_from: 110.days.ago,
        period_to: 55.days.ago
      )

      presenter = CustomProductPossessionPresenter.new(possession.reload)

      assert_not_predicate presenter.owned_for.to_s.strip, :empty?
      assert_equal possession.period_from, presenter.period_from
    end

    presenter = CustomProductPossessionPresenter.new(possessions(:prev_custom_product).reload)
    assert_not_predicate presenter.delete_path, :blank?
    assert_not_predicate presenter.delete_confirm_msg, :blank?
  end

  test 'CustomProductSetupPossessionPresenter targets setup removal URLs' do
    possession = possessions(:current_custom_product)
    setup = setups(:with_products)

    presenter = CustomProductSetupPossessionPresenter.new(possession, setup)
    lookup = SetupPossession.find_by(possession_id: possession.id, setup_id: setup.id)

    assert_predicate lookup, :present?
    assert_equal setup_possession_path(lookup), presenter.delete_path
  end

  test 'SetupPossessionPresenter aligns delete paths with join records on catalogue rows' do
    possession = possessions(:current_product)
    presenter = SetupPossessionPresenter.new(possession, setups(:with_products))

    assert_predicate possession.reload.setup_possession, :present?
    assert_equal setup_possession_path(possession.setup_possession), presenter.delete_path
  end
end
