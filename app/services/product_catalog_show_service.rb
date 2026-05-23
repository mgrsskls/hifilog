# frozen_string_literal: true

class ProductCatalogShowService
  POSSESSION_ORDER = [:prev_owned, :period_from, :period_to, :created_at].freeze
  CONTRIBUTORS_SQL = <<~SQL.squish
    SELECT DISTINCT
      users.id, users.user_name, users.profile_visibility,
      versions.item_type, versions.item_id
    FROM users
    JOIN versions ON users.id = CAST(versions.whodunnit AS integer)
    WHERE versions.item_id = ? AND versions.item_type = 'Product'
  SQL

  def initialize(product:, product_variant: nil, current_user: nil)
    @product = product
    @product_variant = product_variant
    @current_user = current_user
  end

  def call
    result = {
      images: community_gallery_images,
      contributors: product_contributors
    }

    result[:custom_attributes] = @product.custom_attributes_resources if @product.custom_attributes&.any?

    return result unless @current_user

    result.merge(
      possessions: user_possessions,
      bookmark: user_bookmark,
      note: user_note,
      setups: @current_user.setups.includes(:possessions)
    )
  end

  private

  def community_gallery_images
    gallery_possessions.flat_map do |possession|
      PossessionPresenter.new(possession).sorted_images.map { |image| ImagePresenter.new(image) }
    end
  end

  def gallery_possessions
    catalogue_possessions
      .joins(:images_attachments, :user)
      .where(user: { profile_visibility: gallery_profile_visibilities })
      .distinct
      .includes(:user, images_attachments: :blob)
  end

  def gallery_profile_visibilities
    @current_user ? [1, 2] : [2]
  end

  def catalogue_possessions
    if @product_variant
      @product_variant.possessions
    else
      @product.possessions.where(product_variant_id: nil)
    end
  end

  def product_contributors
    ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.sanitize_sql_array([CONTRIBUTORS_SQL, @product.id])
    )
  end

  def user_possessions
    PossessionPresenterService.map_to_presenters(
      @current_user.possessions
        .includes(:product, :product_variant, :product_option, :setup_possession, :setup)
        .where(product_id: @product.id, **possession_variant_scope)
        .order(POSSESSION_ORDER)
    )
  end

  def possession_variant_scope
    if @product_variant
      { product_variant_id: @product_variant.id }
    else
      { product_variant_id: nil }
    end
  end

  def user_bookmark
    if @product_variant
      @current_user.bookmarks.find_by(item_id: @product_variant.id, item_type: 'ProductVariant')
    else
      @current_user.bookmarks.find_by(item_id: @product.id, item_type: 'Product')
    end
  end

  def user_note
    if @product_variant
      @current_user.notes.find_by(product_variant_id: @product_variant.id)
    else
      @current_user.notes.find_by(product_id: @product.id, product_variant_id: nil)
    end
  end
end
