# frozen_string_literal: true

# One statement about one product, from one source, waiting for a decision.
#
# A candidate is not a product. It is what a page said, with a record of which
# part of that page said it. Nothing here reaches the catalogue by itself: a
# person approves it, and only then is a Product written.
#
# The three things that make the review fast are all columns rather than
# calculations:
#
#   * `provenance` holds a source, a URL, a quotation and a confidence for every
#     single field, so a reviewer sees at once whether a price was stated by the
#     shop software or read out of a sentence.
#   * `score` says how complete and how well sourced the row is, so the queue
#     can put the ten-second decisions first.
#   * `match_keys` holds every spelling under which this may already exist, so
#     "is this a duplicate?" is a question the screen answers rather than asks.
class ImportCandidate < ApplicationRecord
  belongs_to :import_batch, optional: true
  belongs_to :brand, optional: true
  belongs_to :reviewed_by, class_name: 'AdminUser', optional: true
  # Set when a person corrects the row by hand. An edited row is not written
  # over by `rake import:load` or `rake import:map`.
  belongs_to :edited_by, class_name: 'AdminUser', optional: true
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true

  # pending   nobody has looked at it
  # approved  a person accepted it; it has not been written yet
  # imported  it is in the catalogue, and `product` says where
  # rejected  a person refused it; the reason is in `decision_note`
  # duplicate a person said this is an existing product, not a new one
  enum :status, {
    pending: 'pending',
    approved: 'approved',
    imported: 'imported',
    rejected: 'rejected',
    duplicate: 'duplicate'
  }, validate: true

  validates :name, presence: true
  validates :brand_slug, presence: true
  validates :source_url, presence: true, uniqueness: { scope: :brand_slug }

  scope :reviewable, -> { where(status: :pending) }
  scope :ready, -> { where(status: :approved) }
  # The queue order: the rows that can be decided quickly, first.
  scope :best_first, -> { order(score: :desc, id: :asc) }
  # A candidate is classified when it names at least one sub category. Both
  # scopes are written against the array so the GIN index serves them.
  scope :validated, -> { where.not(validated_at: nil) }
  scope :unvalidated, -> { where(validated_at: nil) }
  scope :unclassified, -> { where("sub_category_ids = '{}'") }
  scope :classified, -> { where("sub_category_ids <> '{}'") }
  scope :of_sub_category, ->(id) { where('sub_category_ids @> ARRAY[?]::bigint[]', id) }
  scope :of_brand, ->(brand_id) { where(brand_id: brand_id) }
  scope :with_custom_attributes, -> { where.not(custom_attributes: [nil, {}]) }

  # For the sidebar filter: ransack has no built-in "jsonb is not empty"
  # predicate, so this gives it one to search on as a boolean.
  ransacker :has_custom_attributes, type: :boolean do
    Arel.sql("(custom_attributes IS NOT NULL AND custom_attributes <> '{}'::jsonb)")
  end
  # Rows that no person has corrected by hand. The import tasks write only these.
  scope :untouched, -> { where(edited_at: nil) }

  # The verdicts of a second reading that leave the sub categories open. A row
  # with no verdict, or one that agreed with the proposal or could not tell,
  # still takes its sub categories from the mappings. Every other verdict
  # decided them: "corrected" and "classified" wrote them, "no_category"
  # cleared them on purpose, and "out_of_scope" rejected the row.
  MAPPABLE_VERDICTS = [nil, 'agreed', 'unsure'].freeze

  # Rows that `rake import:map` may write: not edited by hand, and not decided
  # by a verdict.
  scope :open_to_mapping, -> { untouched.where(validation_verdict: MAPPABLE_VERDICTS) }

  # Candidates whose shop category has no mapping yet, as
  # [[brand_id, word], count], most first. This is the work list of the mapping
  # screen, and it is one query: the alternative -- asking per candidate --
  # would be eleven thousand queries to render one page.
  def self.unmapped_categories
    counts = reviewable
             .unclassified
             .where.not(source_category: [nil, ''])
             .group(:brand_id, :source_category)
             .order(Arel.sql('COUNT(*) DESC'))
             .count

    known = ImportCategoryMapping.index_for(counts.keys)
    # A brand answered as a whole has no unmapped words left to offer.
    answered_brands = ImportCategoryMapping
                      .where(source_category: ImportCategoryMapping::ALL_CATEGORIES)
                      .pluck(:brand_id).compact.to_set

    counts.reject do |(brand_id, word), _count|
      answered_brands.include?(brand_id) ||
        known.key?([brand_id, word.to_s.downcase]) || known.key?([nil, word.to_s.downcase])
    end
  end

  # Products already in the catalogue that this row may be. Empty means new.
  #
  # The comparison is on the reduced spellings in `match_keys`, which is what
  # makes "CXA81 MkII" and "cxa81mkii" one product. The model number is checked
  # first because the catalogue has a unique index on it.
  def possible_duplicates
    return Product.none if brand_id.blank?

    by_model = model_no.present? ? Product.where(brand_id: brand_id, model_no: model_no) : Product.none
    return by_model if by_model.exists?

    Product.where(brand_id: brand_id).where('lower(name) = ?', name.to_s.downcase)
  end

  # The sub categories this candidate proposes, in the taxonomy's own order.
  #
  # A product may be several things at once -- the Wisdom Audio SUB1 is a
  # subwoofer and an in-wall loudspeaker -- and `Product` has always allowed
  # that. A proposal that could hold only one would have to be wrong for such a
  # product, and nothing downstream could tell.
  def sub_categories
    return SubCategory.none if sub_category_ids.blank?

    SubCategory.where(id: sub_category_ids).order(:order, :name)
  end

  def sub_category_names
    sub_categories.pluck(:name)
  end

  def classified?
    sub_category_ids.present?
  end

  # A form sends the check boxes with an empty value first, so that "none
  # ticked" is also sent. In an array column that empty value would be stored
  # as NULL, so it is removed here.
  def sub_category_ids=(ids)
    super(Array(ids).compact_blank.map(&:to_i).uniq)
  end

  def edited?
    edited_at.present?
  end

  # A second reading checked these categories. It is not approval: a checked
  # candidate is still a proposal, and a person still decides.
  def validated?
    validated_at.present?
  end

  def source_for(field)
    provenance[field.to_s] || {}
  end

  def confidence_for(field)
    source_for(field)['confidence'].to_f
  end

  def display_name
    [name, variant_name].compact_blank.join(' ')
  end

  def to_s = "#{brand_slug} #{display_name}"

  def self.ransackable_associations(_auth_object = nil)
    %w[brand edited_by import_batch product product_variant reviewed_by sub_category]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[brand_id brand_slug created_at custom_attributes decision_note description discontinued
       diy_kit edited_at edited_by_id fingerprint has_custom_attributes id image_urls import_batch_id match_keys
       model_no name price price_currency product_id product_variant_id provenance
       release_year reviewed_at reviewed_by_id score source_category source_platform
       source_url status sub_category_id updated_at validation_verdict variant_name
       variants warnings]
  end
end
