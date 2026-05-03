# frozen_string_literal: true

require 'test_helper'

class ItemPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  def default_url_options
    { host: 'www.example.com', protocol: 'https' }
  end
  test 'routes variant possessions through catalogue variant URLs when present' do
    possession = possessions(:current_product_variant)
    presenter = ItemPresenter.new(possession)

    assert_equal presenter.display_name, possession.product_variant.display_name

    expected_show = possession.product_variant.path
    assert_equal expected_show, presenter.show_path

    assert_includes presenter.edit_path,
                    possession.product&.friendly_id || possession.product_variant.product.friendly_id
    assert_includes presenter.update_path, possession.id.to_s
  end

  test 'product-only possession resolves show path from the catalogue slug' do
    possession = possessions(:current_product)
    presenter = ItemPresenter.new(possession)

    assert_predicate presenter.product_variant, :blank?
    assert_equal product_path(id: presenter.product.friendly_id), presenter.show_path
  end

  test 'initialization with forced product facet ignores companion variant helpers' do
    possession = possessions(:current_product_variant)
    presenter = ItemPresenter.new(possession, :product)

    assert_nil presenter.product_variant
    assert_equal possession.product.name, presenter.short_name
    assert_equal edit_product_path(id: possession.product.friendly_id), presenter.edit_path
    assert_predicate presenter.price_purchase, :blank?
    assert_predicate presenter.price_sale, :blank?
  end

  test 'initialization with forced variant facet keeps variant display metadata' do
    possession = possessions(:current_product_variant)
    presenter = ItemPresenter.new(possession, :product_variant)

    assert_equal possession.product_variant.display_name, presenter.display_name
    assert_equal possession.product_variant.path, presenter.show_path
  end
end
