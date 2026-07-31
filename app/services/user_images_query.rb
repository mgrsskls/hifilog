# frozen_string_literal: true

class UserImagesQuery
  Row = Struct.new(:type, :record, :user, :images, :uploaded_at, keyword_init: true)

  PER_PAGE = 30

  def self.call(page:, per_page: PER_PAGE)
    new(page: page, per_page: per_page).call
  end

  def initialize(page:, per_page: PER_PAGE)
    @page = [page.to_i, 1].max
    @per_page = per_page
  end

  def call
    total = ActiveRecord::Base.connection.select_value(
      "SELECT COUNT(*) FROM (#{union_sql}) AS user_image_rows"
    ).to_i
    raw_rows = ActiveRecord::Base.connection.select_all(
      ActiveRecord::Base.sanitize_sql_array(
        ["#{union_sql} ORDER BY uploaded_at DESC NULLS LAST LIMIT ? OFFSET ?", @per_page, offset]
      )
    )

    enriched = enrich(raw_rows)
    Kaminari.paginate_array(enriched, total_count: total).page(@page).per(@per_page)
  end

  private

  def offset
    (@page - 1) * @per_page
  end

  def union_sql
    <<~SQL.squish
      (
        SELECT
          'possession' AS row_type,
          possessions.id AS record_id,
          MAX(attachments.created_at) AS uploaded_at
        FROM possessions
        INNER JOIN active_storage_attachments attachments
          ON (
            (
              attachments.record_type = 'Possession'
              AND attachments.record_id = possessions.id
              AND attachments.name = 'images'
            )
            OR (
              attachments.record_type = 'CustomProduct'
              AND attachments.record_id = possessions.custom_product_id
              AND attachments.name = 'images'
              AND possessions.custom_product_id IS NOT NULL
            )
          )
        GROUP BY possessions.id
      )
      UNION ALL
      (
        SELECT
          'avatar' AS row_type,
          record_id,
          created_at AS uploaded_at
        FROM active_storage_attachments
        WHERE record_type = 'User' AND name = 'avatar'
      )
      UNION ALL
      (
        SELECT
          'decorative_image' AS row_type,
          record_id,
          created_at AS uploaded_at
        FROM active_storage_attachments
        WHERE record_type = 'User' AND name = 'decorative_image'
      )
    SQL
  end

  def enrich(raw_rows)
    possession_ids = []
    user_ids = []

    raw_rows.each do |row|
      if row['row_type'] == 'possession'
        possession_ids << row['record_id']
      else
        user_ids << row['record_id']
      end
    end

    possessions = Possession.where(id: possession_ids).includes(
      :user,
      :product_option,
      { images_attachments: :blob },
      { product: :brand },
      { product_variant: { product: :brand } },
      { custom_product: [{ images_attachments: :blob }, { sub_categories: :category }] }
    ).index_by { |possession| possession.id.to_s }

    users = User.where(id: user_ids).includes(
      avatar_attachment: :blob,
      decorative_image_attachment: :blob
    ).index_by { |user| user.id.to_s }

    raw_rows.filter_map do |row|
      case row['row_type']
      when 'possession'
        possession_row(possessions[row['record_id'].to_s], row['uploaded_at'])
      when 'avatar'
        avatar_row(users[row['record_id'].to_s], row['uploaded_at'])
      when 'decorative_image'
        decorative_image_row(users[row['record_id'].to_s], row['uploaded_at'])
      end
    end
  end

  def possession_row(possession, uploaded_at)
    return unless possession

    presenter = PossessionPresenterService.map_to_presenters([possession]).first
    images = presenter.images.attached? ? presenter.images.to_a : []

    Row.new(
      type: 'possession',
      record: possession,
      user: possession.user,
      images: images,
      uploaded_at: uploaded_at
    )
  end

  def avatar_row(user, uploaded_at)
    return unless user&.avatar&.attached?

    Row.new(
      type: 'avatar',
      record: user,
      user: user,
      images: [user.avatar],
      uploaded_at: uploaded_at
    )
  end

  def decorative_image_row(user, uploaded_at)
    return unless user&.decorative_image&.attached?

    Row.new(
      type: 'decorative_image',
      record: user,
      user: user,
      images: [user.decorative_image],
      uploaded_at: uploaded_at
    )
  end
end
