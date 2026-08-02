# frozen_string_literal: true

# Turns a Product into a ProductVariant of another Product, and back again.
#
# Both directions create a new row in the target table, re-point every dependent record at it,
# then delete the original. Ids therefore change; anything holding a bare id (or an old slug)
# will not follow. Slug history is dropped on purpose: the URL shape differs between the two
# (/products/:slug vs /products/:product_slug/:slug), so a carried-over slug could not resolve.
#
# A conversion never crosses brands. A variant has no brand of its own — it borrows its parent's —
# so moving a product under a parent from another maker would silently re-attribute it, and every
# possession, note and bookmark that came along with it. Promoting a variant likewise keeps the
# old parent's brand rather than offering a choice.
class ProductConversionService
  class ConversionError < StandardError; end

  # Columns that exist on both tables and mean the same thing.
  SHARED_ATTRIBUTES = %w[
    description
    discontinued
    discontinued_day
    discontinued_month
    discontinued_year
    diy_kit
    model_no
    price
    price_currency
    release_day
    release_month
    release_year
  ].freeze

  # product         - the Product to demote
  # target_product  - the Product it should become a variant of; must share its brand
  # name            - variant name; defaults to the product's own name
  #
  # Returns the new ProductVariant.
  def self.to_variant(product, target_product, name: nil)
    new(product).to_variant(target_product, name:)
  end

  # product_variant   - the ProductVariant to promote; the new product keeps the old parent's brand
  # sub_category_ids  - required; a Product must have at least one sub category
  # custom_attributes - optional spec hash; the admin form offers the old parent's, but nothing
  #                     is inherited unless it is passed in explicitly
  # name              - defaults to the variant's own name, which may be blank
  #
  # Returns the new Product.
  def self.to_product(product_variant, sub_category_ids:, custom_attributes: nil, name: nil)
    new(product_variant).to_product(sub_category_ids:, custom_attributes:, name:)
  end

  def initialize(record)
    @record = record
  end

  def to_variant(target_product, name: nil)
    raise ConversionError, 'No target product given.' if target_product.blank?
    raise ConversionError, 'A product cannot become a variant of itself.' if target_product.id == @record.id

    if target_product.brand_id != @record.brand_id
      raise ConversionError,
            'A product can only become a variant of another product by the same brand.'
    end

    if @record.product_variants.exists?
      raise ConversionError,
            'This product has variants of its own. Move or delete them first, then convert.'
    end

    ActiveRecord::Base.transaction do
      variant = ProductVariant.new(shared_attributes)
      variant.product = target_product
      variant.name = name.presence || @record.name
      variant.discontinued = @record.discontinued? # not nullable on variants
      save_or_raise(variant)

      # A variant's options hang off the variant alone, while possessions and notes keep pointing
      # at the parent product as well.
      move_dependents(product_id: target_product.id, product_variant_id: variant.id, option_product_id: nil)
      repoint_polymorphic(to: variant)

      discard_original
      variant
    end
  end

  def to_product(sub_category_ids:, custom_attributes: nil, name: nil)
    ActiveRecord::Base.transaction do
      product = Product.new(shared_attributes)
      product.brand_id = @record.product.brand_id
      product.sub_category_ids = Array(sub_category_ids).compact_blank
      product.custom_attributes = custom_attributes.presence
      product.name = name.presence || @record.name
      save_or_raise(product)

      move_dependents(product_id: product.id, product_variant_id: nil, option_product_id: product.id)
      repoint_polymorphic(to: product)

      discard_original
      product
    end
  end

  private

  def shared_attributes
    @record.attributes.slice(*SHARED_ATTRIBUTES)
  end

  def save_or_raise(record)
    return if record.save

    raise ConversionError, record.errors.full_messages.to_sentence
  end

  # update_all on purpose, in one statement per table: these rows are only having a foreign key
  # rewritten, and loading each one to re-validate would fire Possession's image callbacks and
  # touch the parent product once per row. The uniqueness rules the cop is guarding are already
  # satisfied — the new record's id is fresh, so no (user, product, variant) pair it lands on can
  # collide with an existing one.
  # rubocop:disable Rails/SkipsModelValidations
  def move_dependents(product_id:, product_variant_id:, option_product_id:)
    @record.possessions.update_all(product_id:, product_variant_id:)
    @record.notes.update_all(product_id:, product_variant_id:)
    @record.product_options.update_all(product_id: option_product_id, product_variant_id:)
  end

  # Bookmarks and paper_trail versions are both keyed by (type, id), so the whole history and
  # every user's bookmark follows the record across the conversion.
  def repoint_polymorphic(to:)
    Bookmark.where(item_type: @record.class.name, item_id: @record.id)
            .update_all(item_type: to.class.name, item_id: to.id)

    PaperTrail::Version.where(item_type: @record.class.name, item_id: @record.id)
                       .update_all(item_type: to.class.name, item_id: to.id)
  end
  # rubocop:enable Rails/SkipsModelValidations

  # Everything worth keeping has already been moved off the original, so reload before destroying
  # to stop `dependent: :destroy` from acting on the stale in-memory associations. PaperTrail is
  # muted so the delete does not leave an orphan version under the old type, which would otherwise
  # be the only row left pointing at an id that no longer exists.
  def discard_original
    FriendlyId::Slug.where(sluggable_type: @record.class.name, sluggable_id: @record.id).delete_all

    PaperTrail.request(enabled: false) do
      @record.reload.destroy!
    end
  end
end
