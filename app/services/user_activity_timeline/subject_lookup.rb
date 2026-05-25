# frozen_string_literal: true

# Preloads possessions, catalog records, and presenters referenced by activity rows.
class UserActivityTimeline::SubjectLookup
  include Rails.application.routes.url_helpers

  def initialize(user:, activities:)
    @user = user
    @activities = activities
    build_indexes!
  end

  def possession(id)
    @possessions_by_id[id.to_i]
  end

  def possession_presenter(possession)
    return nil unless possession

    @possession_presenters_by_id[possession.id] ||
      PossessionPresenterService.map_to_presenters([possession]).first
  end

  def possession_gallery_image(attachment_id)
    return nil if attachment_id.blank?

    attachment = @image_attachments_by_id[attachment_id.to_i]
    return nil unless attachment&.blob

    if attachment.record_type == 'Possession'
      possession = @possessions_by_id[attachment.record_id]
      attachment.association(:record).target = possession if possession
    end

    ImagePresenter.new(attachment)
  end

  def setup_product_activity_product_url(meta, possession)
    presenter = possession_presenter(possession)
    return presenter.show_path if presenter

    if (cid = meta['custom_product_id'].presence&.to_i)&.positive?
      custom_product = @user.custom_products.find_by(id: cid)
      if custom_product
        return user_custom_product_path(user_id: @user.user_name.downcase, id: custom_product.friendly_id)
      end
    end

    pid = meta['product_id'].presence&.to_i
    if pid&.positive?
      product = @products_by_id[pid]
      if product
        vid = meta['product_variant_id'].presence&.to_i
        if vid&.positive?
          variant = @variants_by_key[[pid, vid]]
          return variant.path if variant
        end
        return product_path(id: product.friendly_id)
      end
    end

    meta['product_url'].presence || '#'
  end

  private

  def build_indexes!
    possession_ids = Set.new
    product_ids = Set.new
    variant_keys = Set.new

    @activities.each do |activity|
      possession_ids << activity.subject_id if activity.subject_type == 'Possession'

      next unless %w[setup_product_added setup_product_removed].include?(activity.verb)

      meta = activity.metadata || {}
      pid = meta['possession_id'].presence&.to_i
      possession_ids << pid if pid&.positive?

      prod_id = meta['product_id'].presence&.to_i
      next unless prod_id&.positive?

      product_ids << prod_id
      vid = meta['product_variant_id'].presence&.to_i
      variant_keys << [prod_id, vid] if vid&.positive?
    end

    unique_possessions =
      Possession.where(id: possession_ids.to_a)
                .includes(
                  { product: :brand },
                  { product_variant: { product: :brand } },
                  { custom_product: [:user] },
                  :user
                )
                .to_a

    image_attachment_ids =
      @activities.filter_map do |activity|
        next unless activity.verb == 'possession_image_uploaded'

        activity.metadata&.[]('image_attachment_id')&.to_i
      end
    @image_attachments_by_id =
      if image_attachment_ids.empty?
        {}
      else
        ActiveStorage::Attachment.where(id: image_attachment_ids.uniq)
                                 .includes(:blob, record: :user)
                                 .index_by(&:id)
      end

    @possessions_by_id = unique_possessions.index_by(&:id)
    @possession_presenters_by_id = unique_possessions.zip(
      PossessionPresenterService.map_to_presenters(unique_possessions)
    ).to_h { |possession, presenter| [possession.id, presenter] }

    @products_by_id = Product.where(id: product_ids.to_a).includes(:brand).index_by(&:id)
    @variants_by_key = {}
    return if variant_keys.empty?

    ProductVariant.where(product_id: variant_keys.map(&:first).uniq).includes(product: :brand).find_each do |variant|
      @variants_by_key[[variant.product_id, variant.id]] = variant
    end
  end
end
