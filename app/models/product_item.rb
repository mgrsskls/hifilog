# frozen_string_literal: true

class ProductItem < ApplicationRecord
  include PgSearch::Model
  include ReleaseDate
  include PgSearchByName

  self.primary_key = :id # needed for pg_search
  # Tell Rails to use created_at for .first and .last instead of the UUID id
  self.implicit_order_column = 'created_at'

  pg_search_by_name(against: {
                      name: 'A',
                      variant_name: 'B',
                      model_no: 'B',
                      brand_name: 'A'
                    })

  belongs_to :brand
  has_many :product_options
  # Possessions reference products.id / product_variants.id, not the product_items view UUID primary key.
  has_many :product_possessions,
           class_name: 'Possession',
           foreign_key: :product_id,
           primary_key: :product_id,
           inverse_of: false
  has_many :variant_possessions,
           class_name: 'Possession',
           foreign_key: :product_variant_id,
           primary_key: :product_variant_id,
           inverse_of: false
  has_many :product_variants,
           class_name: 'ProductVariant',
           foreign_key: :product_id,
           primary_key: :product_id,
           inverse_of: false

  # Possessions tied to the base product row only (product_id). Variant-only possessions often have a nil product_id.
  def possessions
    item_type == 'Product' ? product_possessions : variant_possessions
  end

  def readonly?
    true
  end

  def sub_categories
    SubCategory.joins(:products).where(products: { id: product_id }).distinct
  end

  def self.preload_list_possession_images(relation)
    records = relation.records
    product_rows = records.select { |record| record.item_type == 'Product' }
    variant_rows = records.select { |record| record.item_type == 'ProductVariant' }

    if product_rows.any?
      ActiveRecord::Associations::Preloader.new(
        records: product_rows,
        associations: [
          { product_possessions: [:user, { images_attachments: :blob }] },
          { product_variants: { possessions: [:user, { images_attachments: :blob }] } }
        ]
      ).call
    end

    if variant_rows.any?
      ActiveRecord::Associations::Preloader.new(
        records: variant_rows,
        associations: [
          { variant_possessions: [:user, { images_attachments: :blob }] }
        ]
      ).call
    end

    relation
  end

  def list_possessions_for_thumbnail
    if item_type == 'ProductVariant'
      variant_possessions.to_a
    else
      (product_possessions.to_a + product_variants.flat_map(&:possessions)).uniq(&:id)
    end
  end

  def earliest_list_possession_with_images(user_signed_in:)
    candidates = list_possessions_for_thumbnail.select do |possession|
      user = possession.user
      next false unless user

      is_visible = user.visible?

      if user_signed_in
        is_visible || user.logged_in_only?
      else
        is_visible
      end
    end
    candidates.select! { |possession| possession.images.attached? }
    candidates.min_by { |possession| possession.created_at || Time.zone.at(0) }
  end

  def list_image_cache_version(user_signed_in:)
    possession = earliest_list_possession_with_images(user_signed_in: user_signed_in)
    return 'none' unless possession

    attachment = PossessionPresenter.new(possession).highlighted_image
    img_part = if attachment
                 "#{attachment.id}-#{attachment.blob_id}-#{attachment.created_at.to_fs(:usec)}"
               else
                 'none'
               end
    "#{possession.id}-#{possession.highlighted_image_id}-#{possession.created_at&.to_fs(:usec)}-#{img_part}"
  end
end
