# frozen_string_literal: true

require 'test_helper'

class PossessionPresenterTest < ActiveSupport::TestCase
  ONE_BY_ONE_PNG = Base64.decode64(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  ).freeze

  setup do
    @possession = possessions(:prev_product).tap(&:reload)
  end

  test 'delegates monetised timestamps and durations for previous possessions' do
    travel_to Time.zone.local(2026, 3, 28, 12, 0, 0) do
      @possession.update!(period_from: 100.days.ago, period_to: 50.days.ago)

      presenter = PossessionPresenter.new(@possession.reload)

      if presenter.price_purchase.nil?
        assert_nil @possession.price_purchase
      else
        assert_equal @possession.price_purchase, presenter.price_purchase
      end
      phrase = presenter.owned_for
      assert_not_predicate phrase.to_s.strip, :empty?
    end
  end

  test 'highlighted_image prefers flagged attachment ordering' do
    possession = possessions(:current_product)
    possession.images.purge if possession.images.attached?

    possession.images.attach(
      io: StringIO.new(ONE_BY_ONE_PNG),
      filename: 'a.png',
      content_type: 'image/png'
    )
    possession.images.attach(
      io: StringIO.new(ONE_BY_ONE_PNG),
      filename: 'b.png',
      content_type: 'image/png'
    )

    highlighted = possession.images.reload.order(:created_at).last
    possession.update_columns(highlighted_image_id: highlighted.id) # rubocop:disable Rails/SkipsModelValidations

    presenter = PossessionPresenter.new(possession.reload)

    assert_equal highlighted.blob_id, presenter.highlighted_image.blob_id
    ids = presenter.sorted_images.map(&:id)
    assert_equal highlighted.id, ids.first
  end
end
