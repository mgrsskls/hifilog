# frozen_string_literal: true

require 'test_helper'

class CustomAttributeReadingTest < ActiveSupport::TestCase
  setup do
    @weight = custom_attributes(:four)
    @weight.units = %w[lb kg]
    @dimensions = custom_attributes(:six)
  end

  test 'a lone figure is followed by its conversion' do
    assert_equal [%w[15 kg], %w[33 lb]], figures(@weight, { 'value' => 15.0, 'unit' => 'kg' })
    assert_equal [%w[33 lb], %w[15 kg]], figures(@weight, { 'value' => 33.0, 'unit' => 'lb' })
  end

  test 'two stated figures are shown as stated, without a conversion' do
    entry = { 'value' => 15.0, 'unit' => 'kg', 'second' => { 'value' => 34.0, 'unit' => 'lb' } }

    assert_equal [%w[15 kg], %w[34 lb]], figures(@weight, entry)
  end

  test 'a definition without a pair shows the stated figure only' do
    @weight.units = %w[kg]

    assert_equal [%w[15 kg]], figures(@weight, { 'value' => 15.0, 'unit' => 'kg' })
  end

  test 'a multi input value has one line for each input' do
    entry = { 'value' => { 'w' => 43.0, 'h' => 12.0 }, 'unit' => 'cm',
              'second' => { 'value' => { 'w' => 17.0 }, 'unit' => 'in' } }
    lines = CustomAttributeReading.new(@dimensions, entry).lines

    assert_equal %w[w h], lines.map(&:input)
    assert_equal([%w[43 cm], %w[17 in]], lines.first.figures.map { |figure| [figure.number, figure.unit] })
    # No stated inch figure for the height, so it is converted.
    assert_equal([['12', 'cm'], ['4.7', 'in']], lines.last.figures.map { |figure| [figure.number, figure.unit] })
  end

  test 'an input stated only in the second figure has its own line' do
    entry = { 'value' => { 'w' => 43.0 }, 'unit' => 'cm',
              'second' => { 'value' => { 'w' => 17.0, 'h' => 4.7 }, 'unit' => 'in' } }
    lines = CustomAttributeReading.new(@dimensions, entry).lines

    assert_equal %w[w h], lines.map(&:input)
    assert_equal([%w[4.7 in], %w[12 cm]], lines.last.figures.map { |figure| [figure.number, figure.unit] })
  end

  test 'an entry without a unit reads in the first unit of the definition' do
    assert_equal [['3', 'lb'], ['1.4', 'kg']], figures(@weight, { 'value' => 3.0 })
  end

  test 'a deleted definition shows the stored figure only' do
    assert_equal [%w[15 kg]], figures(nil, { 'value' => 15.0, 'unit' => 'kg' })
  end

  test 'primary_figure is the metric one, stated or converted' do
    assert_equal %w[15 kg], primary(@weight, { 'value' => 33.0, 'unit' => 'lb' })
    assert_equal %w[15 kg],
                 primary(@weight, { 'value' => 15.0, 'unit' => 'kg', 'second' => { 'value' => 33.0, 'unit' => 'lb' } })
    assert_nil CustomAttributeReading.new(@weight, { 'unit' => 'kg' }).primary_figure
  end

  private

  def figures(definition, entry)
    CustomAttributeReading.new(definition, entry).lines.first.figures.map { |figure| [figure.number, figure.unit] }
  end

  def primary(definition, entry)
    figure = CustomAttributeReading.new(definition, entry).primary_figure
    [figure.number, figure.unit]
  end
end
