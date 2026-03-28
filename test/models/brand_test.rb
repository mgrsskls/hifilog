require 'test_helper'

class BrandTest < ActiveSupport::TestCase
  test 'validations' do
    brand = Brand.new
    assert_not brand.valid?
    assert brand.errors[:name].any?
  end

  test 'name uniqueness' do
    brand1 = brands(:one)
    brand2 = Brand.new(name: brand1.name)
    assert_not brand2.valid?
    assert brand2.errors[:name].any?
  end

  test 'slug uniqueness' do
    brand1 = brands(:one)
    brand2 = Brand.new(name: 'Different Name')
    brand2.slug = brand1.slug
    assert_not brand2.valid?
    assert brand2.errors[:slug].any?
  end

  test 'country_code_has_allowed_value validation' do
    brand = Brand.new(name: 'Test Brand', country_code: 'INVALID')
    assert_not brand.valid?
    assert brand.errors[:country_code].any?

    brand.country_code = 'DE'
    assert brand.valid?
  end

  test 'founded_year validation' do
    brand = Brand.new(name: 'name', founded_year: 'not_a_number')
    assert_not brand.valid?
    assert brand.errors[:founded_year].any?

    brand = Brand.new(name: 'name', founded_year: 1920)
    assert brand.valid?
  end

  test 'country_name' do
    brand = brands(:one)
    brand.update!(country_code: 'DE')
    assert_equal 'Germany', brand.country_name
  end

  test 'founded_date' do
    brand = Brand.new(name: 'brand')
    assert_nil brand.founded_date

    brand.update!(founded_year: 2020, founded_month: 6, founded_day: 15)
    assert_equal Date.new(2020, 6, 15), brand.founded_date
  end

  test 'discontinued_date' do
    brand = Brand.new(name: 'brand')
    assert_nil brand.discontinued_date

    brand.update!(discontinued: true, discontinued_year: 2023, discontinued_month: 6, discontinued_day: 15)
    assert_equal Date.new(2023, 6, 15), brand.discontinued_date
  end

  test 'continued?' do
    brand = Brand.new(discontinued: false)
    assert brand.continued?

    brand.discontinued = true
    assert_not brand.continued?

    brand.discontinued = nil
    assert_not brand.continued?
  end

  test 'display_name' do
    brand = brands(:one)
    assert_equal brand.name, brand.display_name
  end

  test 'url' do
    brand = brands(:one)
    assert_match brand.friendly_id, brand.url
  end

  test 'categories' do
    brand = brands(:one)
    categories = brand.categories
    assert categories.is_a?(Array)
    assert(categories.all?(Category))
  end

  test 'formatted_description without description' do
    brand = Brand.new(name: 'Test', country_code: 'DE', founded_year: 2020)
    desc = brand.formatted_description
    assert_not_nil desc
    assert_includes desc, 'Germany'
    assert_includes desc, 'Test'
  end

  test 'formatted_description with all attributes' do
    brand = Brand.new(
      name: 'Test Brand',
      country_code: 'US',
      founded_year: 2000,
      discontinued_year: 2020,
      discontinued: true
    )
    desc = brand.formatted_description
    assert_not_nil desc
    assert_includes desc, 'was'
    assert_includes desc, 'founded in 2000'
    assert_includes desc, 'discontinued in 2020'
  end

  test 'formatted_description with custom description' do
    brand = Brand.new(name: 'Test', description: '**Bold text**')
    desc = brand.formatted_description
    assert_includes desc, '<strong>Bold text</strong>'
  end
end
