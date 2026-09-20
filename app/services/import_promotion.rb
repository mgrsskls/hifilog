# frozen_string_literal: true

# Turns an approved candidate into a catalogue product.
#
# This is the only place where anything an importer produced becomes a
# `Product`, which is why it is a service and not a few lines in a rake task:
# the rule that nothing reaches the catalogue unreviewed is worth being able to
# test, and a rake task cannot be tested.
#
# What it refuses is as important as what it writes. A candidate that cannot
# become a valid product is left as it is, with the reason, and stays approved
# so a later run can try again after the reason is removed. Nothing is written
# half way: a product and its variant are written in one transaction.
class ImportPromotion
  Result = Struct.new(:candidate, :product, :error, keyword_init: true) do
    def success? = error.nil?
  end

  def self.call(candidate)
    new(candidate).call
  end

  # Every approved candidate, oldest first. Returns the results, so the caller
  # -- a rake task, or a screen -- decides how to report them.
  def self.run_all(scope = ImportCandidate.ready)
    scope.includes(:brand).order(:id).map { |candidate| call(candidate) }
  end

  def initialize(candidate)
    @candidate = candidate
  end

  def call
    return failure('already imported') if @candidate.imported?
    return failure('no brand in the catalogue for this slug') if @candidate.brand.blank?

    sub_categories = @candidate.sub_categories.to_a
    return failure('no sub category') if sub_categories.empty?

    product = nil
    ActiveRecord::Base.transaction do
      product = build_product(sub_categories)
      product.save!
      create_variant(product)
      @candidate.update!(status: 'imported', product: product, reviewed_at: Time.current)
    end
    Result.new(candidate: @candidate, product: product)
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages.to_sentence)
  end

  private

  def build_product(sub_categories)
    product = Product.new(
      brand: @candidate.brand,
      name: @candidate.name,
      model_no: @candidate.model_no,
      description: @candidate.description,
      price: @candidate.price,
      price_currency: @candidate.price_currency,
      release_year: @candidate.release_year,
      discontinued: @candidate.discontinued || false,
      diy_kit: @candidate.diy_kit || false,
      custom_attributes: @candidate.custom_attributes.presence || {},
      sub_categories: sub_categories
    )
    # A price with no currency is a number without a meaning, and the model
    # refuses it. The price is dropped rather than the product: everything else
    # the page stated is still worth having, and the review can see that the
    # price is missing.
    product.price = nil if product.price.present? && product.price_currency.blank?
    product.comment = "imported from #{@candidate.source_url}"
    product
  end

  # The version words that the shop wrote into the product name become a
  # variant, which is where this catalogue keeps them.
  def create_variant(product)
    return if @candidate.variant_name.blank?

    ProductVariant.create!(
      product: product,
      name: @candidate.variant_name,
      discontinued: @candidate.discontinued || false
    )
  end

  def failure(reason)
    Result.new(candidate: @candidate, error: reason)
  end
end
