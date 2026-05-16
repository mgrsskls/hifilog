# frozen_string_literal: true

class Possession < ApplicationRecord
  include Image

  enum :purchase_condition, {
    first_hand: 0,
    second_hand: 1,
    b_stock: 2
  }, allow_nil: true

  scope :for_stats, -> { includes(:product_variant, :custom_product, product: :brand) }
  scope :current, -> { where.not(prev_owned: true) }
  scope :with_period, -> { where.not(period_from: nil) }
  scope :with_images, lambda {
    where(<<~SQL.squish)
      EXISTS (
        SELECT 1 FROM active_storage_attachments
        WHERE record_type = 'Possession'
          AND record_id = possessions.id
          AND name = 'images'
      )
      OR EXISTS (
        SELECT 1 FROM active_storage_attachments
        WHERE record_type = 'CustomProduct'
          AND record_id = possessions.custom_product_id
          AND name = 'images'
          AND possessions.custom_product_id IS NOT NULL
      )
    SQL
  }
  scope :recent_with_images, lambda { |limit = 5|
    current
      .with_images
      .order(Arel.sql('possessions.created_at DESC NULLS LAST'))
      .limit(limit)
  }

  belongs_to :user
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true
  belongs_to :custom_product, optional: true
  belongs_to :product_option, optional: true

  has_one :setup_possession, dependent: :destroy
  has_one :setup, through: :setup_possession
  has_many_attached :images do |attachable|
    attachable.variant :thumb, resize_to_fill: [640, 640], format: :webp
    attachable.variant :large, resize_to_limit: [1200, 1200], format: :webp
  end

  validate :validate_image_content_type, :validate_image_file_size, on: :update

  attr_accessor :delete_image

  validates :custom_product_id, uniqueness: true, allow_nil: true
  validates :price_purchase, absence: true, if: :gift?
  validates :price_purchase_currency, absence: true, if: :gift?

  before_validation :clear_purchase_price_when_gift
  before_save :stamp_moved_to_previous_at_when_became_previous
  before_save :capture_image_attachment_ids_before_save

  before_destroy :hide_user_activities_for_possession
  after_commit :sync_user_activities_for_possession, on: [:create, :update]
  after_commit :record_possession_image_upload_activities, on: [:create, :update]

  def brand
    return product_variant.product.brand if product_variant.present?
    return product.brand if product.present?

    nil
  end

  def purchase_condition_label
    return if purchase_condition.blank?

    I18n.t("activerecord.enums.possession.purchase_condition.#{purchase_condition}")
  end

  def gift_label
    return unless gift?

    I18n.t('possession.gift_label')
  end

  def purge_images_by_id!(ids)
    Array(ids).compact_blank.each do |id|
      attachment = images.find(id)
      UserActivities::Recorder.possession_image_deleted(self, image_attachment: attachment)
      attachment.purge
    end
  end

  def duration
    return nil if period_from.nil?

    if prev_owned
      return nil if period_to.nil?

      return period_to - period_from
    end

    Time.zone.now - period_from
  end

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      user_id
      user_id_eq
      price_purchase
      price_purchase_currency
      price_sale
      price_sale_currency
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
  # :nocov:

  private

  def clear_purchase_price_when_gift
    return unless gift?

    self.price_purchase = nil
    self.price_purchase_currency = nil
  end

  def capture_image_attachment_ids_before_save
    @image_attachment_ids_before_save = images.attachments.map(&:id)
  end

  def record_possession_image_upload_activities
    before_ids = @image_attachment_ids_before_save || []
    new_ids = images.attachments.map(&:id) - before_ids
    return if new_ids.empty?

    presenter = PossessionPresenterService.map_to_presenters([self]).first
    attachments_by_id = images.attachments.index_by(&:id)
    new_ids.each do |attachment_id|
      attachment = attachments_by_id[attachment_id]
      next unless attachment

      UserActivities::Recorder.possession_image_uploaded(
        self, image_attachment: attachment, presenter:
      )
    end
  ensure
    @image_attachment_ids_before_save = nil
  end

  def sync_user_activities_for_possession
    UserActivities::Recorder.sync_possession(self)
  end

  def hide_user_activities_for_possession
    UserActivities::Recorder.hide_possession_activities!(self)
  end

  # Any transition from current collection to previous (not only +move_to_prev_owneds+) should record when that
  # happened so the activity feed can show "moved" instead of "added to previous". New rows created as
  # +prev_owned: true+ are skipped (+persisted?+ is false on first save).
  def stamp_moved_to_previous_at_when_became_previous
    return unless prev_owned?
    return if moved_to_previous_at.present?
    return unless persisted?
    return unless attribute_in_database(:prev_owned) == false

    self.moved_to_previous_at = Time.current
    self.setup = nil
  end
end
