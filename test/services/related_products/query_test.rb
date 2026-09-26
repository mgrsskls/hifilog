# frozen_string_literal: true

require 'test_helper'

# Candidate fetching, with targets built by hand so these tests do not depend on the graph. Sub
# category one is Headphone Amplifiers, two is Over-Ear Headphones, three is Pre-Amp / Driver
# Tubes. `with_variants` sits in two and has two current variants; `one` is the more complete.
class RelatedProducts::QueryTest < ActiveSupport::TestCase
  def target(*sub_categories, gates: [])
    RelatedProducts::Resolver::Target.new(
      role: :headphone,
      sub_category_ids: sub_categories.map { |name| sub_categories(name).id },
      gates:,
      same_brand: false
    )
  end

  def presence_gate(attribute)
    RelatedProducts::Resolver::Gate.new(attribute:, option_ids: [], negate: false, presence: true)
  end

  def groups(product, *targets)
    RelatedProducts::Query.new(product:, targets:).call
  end

  test 'a discontinued product is shown as its most complete current variant' do
    products(:with_variants).update_column(:discontinued, true) # rubocop:disable Rails/SkipsModelValidations

    items = groups(products(:one), target(:two)).first.items

    # item_id must repeat the product_items view's id expression, or the variant row is not found.
    assert_includes items.map(&:product_variant_id), product_variants(:one).id
    assert_not_includes items.map(&:product_variant_id), product_variants(:three).id
  end

  test 'a current product is shown as itself, not as a variant' do
    items = groups(products(:one), target(:two)).first.items
    item = items.find { |candidate| candidate.product_id == products(:with_variants).id }

    assert item, 'expected with_variants among the candidates'
    assert_nil item.product_variant_id
  end

  test 'a product in two target sub categories is grouped under the first one declared' do
    product = products(:driver_tube)
    product.sub_categories << sub_categories(:two)
    product.update_column(:custom_attributes, { 'related_products_test' => '1' }) # rubocop:disable Rails/SkipsModelValidations
    gates = [presence_gate('related_products_test')]

    assert_equal sub_categories(:three).id,
                 groups(products(:one), target(:three, :two, gates:)).first.sub_category_id
    assert_equal sub_categories(:two).id,
                 groups(products(:one), target(:two, :three, gates:)).first.sub_category_id
  end

  test 'the source product is not its own candidate' do
    items = groups(products(:tube_headphone_amp), target(:one, gates: [presence_gate('amplifier_type')])).first.items

    assert_equal [products(:solid_state_headphone_amp).id], items.map(&:product_id)
  end
end
