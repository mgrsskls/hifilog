# frozen_string_literal: true

# "What this shop calls a category, this catalogue calls a sub category."
#
# A shop states a category for most of its products, but it is the shop's own
# word: "Subwoofer Outlet", "Visual Experience", "Accessoires", "physical". The
# word is never written to the catalogue. It is mapped, one time, and the
# mapping then applies to every later run.
#
# The measurement that this is built on: of 10904 candidates from 128 shops,
# 68% carried a category, and those were 1039 distinct (brand, word) pairs. One
# decision covers seven products on average and 1351 in the largest case.
#
# Two shapes of mapping, and the narrower one wins:
#
#   brand_id nil  "Headphones" means over-ear headphones, for every shop.
#   brand_id set  This shop's "Reference" means floorstanding loudspeakers.
#
# A mapping may also state that the products under a word are discontinued.
# "Archived Digital Cables" says both what they are and that they are gone, and
# nothing in the markup carries the second part: an archived product is simply
# missing from the shop's availability fields. A mapping that states only this
# is valid -- "Archived Audio Cables" names cables of several kinds, so it
# decides the state and leaves the category to the review.
#
# A mapping may name more than one sub category. A shop that writes "In-Wall
# Subwoofers" means both, and a product may be both -- so the decision must be
# able to say so.
#
# `out_of_scope` is the third answer, and it is a decision like the others: a
# shop's "Vinyl" or "Merch" is refused one time rather than once per run.
class ImportCategoryMapping < ApplicationRecord
  belongs_to :brand, optional: true
  belongs_to :decided_by, class_name: 'AdminUser', optional: true

  before_validation { self.sub_category_ids = Array(sub_category_ids).compact_blank.map(&:to_i).uniq }

  # "*" means every word of one brand. It is the answer when a brand is wrong
  # for this catalogue as a whole rather than in one of its ranges -- a maker of
  # televisions and car radios that also sells a soundbar. Writing twenty
  # refusals for such a brand hides that fact as twenty small ones.
  ALL_CATEGORIES = '*'

  validates :source_category, presence: true,
                              uniqueness: { scope: :brand_id, case_sensitive: false }
  validate :whole_brand_rule_needs_a_brand
  validate :must_decide_something
  validate :sub_categories_must_exist

  scope :general, -> { where(brand_id: nil) }

  # The mapping for one shop's word, or nil.
  #
  # The brand's own mapping is preferred over the general one. Two queries would
  # be the obvious way; this is one, ordered so that the brand's own row sorts
  # first, because the review screen asks this for every row it renders.
  def self.for(brand_id, source_category)
    return nil if source_category.blank?

    where(source_category: source_category)
      .where(brand_id: [brand_id, nil])
      .order(Arel.sql('brand_id IS NULL'))
      .first
  end

  # Every mapping at once, as { [brand_id, word] => mapping }, for a screen that
  # renders hundreds of rows. The general mappings are keyed by [nil, word].
  # True when this rule answers every category of one brand. Public, because
  # `import:map` asks it to decide which candidates a rule covers.
  def whole_brand?
    source_category == ALL_CATEGORIES
  end

  def sub_categories
    return SubCategory.none if sub_category_ids.blank?

    SubCategory.where(id: sub_category_ids).order(:order, :name)
  end

  def self.index_for(pairs)
    words = pairs.map(&:last).compact.uniq
    return {} if words.empty?

    brand_ids = pairs.map(&:first).compact.uniq
    where(source_category: words)
      .where(brand_id: brand_ids + [nil])
      .index_by { |mapping| [mapping.brand_id, mapping.source_category.to_s.downcase] }
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[brand decided_by sub_category]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[brand_id created_at decided_by_id id id_value out_of_scope source_category sub_category_id
       updated_at]
  end

  private

  # A mapping row that neither names a sub category nor refuses the word decides
  # nothing, and would silently leave its candidates unclassified for ever.
  def whole_brand_rule_needs_a_brand
    return unless whole_brand?
    return if brand_id.present?

    errors.add(:brand, 'must be named for a rule that answers every category')
  end

  def must_decide_something
    return if out_of_scope? || sub_category_ids.present? || !discontinued.nil?

    errors.add(:sub_categories,
               'must be chosen, or the category marked as out of scope, or a ' \
               'discontinued state stated')
  end

  # An id that names nothing would classify candidates into a category that
  # cannot be rendered, and the failure would only appear at promotion.
  def sub_categories_must_exist
    return if sub_category_ids.blank?

    missing = sub_category_ids.map(&:to_i) - SubCategory.where(id: sub_category_ids).pluck(:id)
    errors.add(:sub_category_ids, "do not exist: #{missing.join(', ')}") if missing.any?
  end
end
