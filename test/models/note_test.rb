# frozen_string_literal: true

require 'test_helper'

class NoteTest < ActiveSupport::TestCase
  test 'text presence validation' do
    note = Note.new(product_id: products(:one).id, user_id: users(:one).id)
    assert_not note.valid?
    assert note.errors[:text].any?
  end

  test 'product presence validation' do
    note = Note.new(text: 'text', user_id: users(:one).id)
    assert_not note.valid?
    assert note.errors[:product].any?
  end

  test 'product_variant uniqueness per user and product' do
    user = users(:one)
    product = products(:one)
    product_variant = product_variants(:one)

    Note.create!(
      text: 'first note',
      user_id: user.id,
      product_id: product.id,
      product_variant_id: product_variant.id
    )

    note2 = Note.new(
      text: 'second note',
      user_id: user.id,
      product_id: product.id,
      product_variant_id: product_variant.id
    )
    assert_not note2.valid?
    assert note2.errors[:product_variant].any?
  end

  test 'different product variants can have notes' do
    user = users(:one)
    product = products(:one)
    variant1 = product_variants(:one)
    variant2 = product_variants(:two)

    Note.create!(
      text: 'variant 1 note',
      user_id: user.id,
      product_id: product.id,
      product_variant_id: variant1.id
    )

    note2 = Note.new(
      text: 'variant 2 note',
      user_id: user.id,
      product_id: product.id,
      product_variant_id: variant2.id
    )
    assert note2.valid?
  end

  test 'associations' do
    note = Note.first
    assert_respond_to note, :product
    assert_respond_to note, :product_variant
    assert_respond_to note, :user
  end
end
