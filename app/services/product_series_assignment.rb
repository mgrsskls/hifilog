# frozen_string_literal: true

# Saves the product checkboxes of the dialog of a product series page (the rows it had loaded), in
# one transaction. See docs/product-series.md, "Assign products on the series page".
#
# Two rules make the result of a submit independent of the order of the products:
#
# * The clash is looked for in the **end state**, before anything is written. A product saved on
#   its own would be compared with the rows written before it, so a set of changes with a valid
#   end state could fail in the middle (for example when two products change places between two
#   series). The uniqueness validation of the product name is thus skipped during these saves
#   (Product#skip_name_uniqueness), because this class has already made the same check.
# * A product that can not change is **left as it is**; the other products still change. Without
#   this, one clash discards all the work of the submit.
class ProductSeriesAssignment
  # product:  the product that did not change
  # conflict: the product of the brand that already has this name in the same group, or nil
  # errors:   the messages of the failed save, or nil
  Skipped = Struct.new(:product, :conflict, :errors, keyword_init: true)

  # changed: the products that changed
  # skipped: Skipped entries, in the order of the list
  Result = Struct.new(:changed, :skipped, keyword_init: true)

  # series:       the ProductSeries of the page
  # changes:      the products whose series the submit changes
  # selected_ids: the ids of the checked products (a product not in it leaves the series)
  def initialize(series:, changes:, selected_ids:)
    @series = series
    @changes = changes
    @selected_ids = selected_ids
  end

  def call
    changed = []
    skipped = []

    ActiveRecord::Base.transaction do
      planned, skipped = plan
      changed, failed = write(planned)
      skipped += failed
    end

    Result.new(changed:, skipped: skipped.sort_by { |entry| @changes.index(entry.product) || 0 })
  end

  private

  # [[product, target series], …] and the Skipped entries of the products that would get a name
  # that another product of the brand already has in the same group.
  def plan
    taken = occupied_groups
    planned = []
    skipped = []

    @changes.each do |product|
      target = @selected_ids.include?(product.id) ? @series : nil
      key = group_key(target&.id, product.name, product.model_no)
      conflict = taken[key]

      if conflict
        skipped << Skipped.new(product:, conflict:)
      else
        taken[key] = product
        planned << [product, target]
      end
    end

    [planned, skipped]
  end

  def write(planned)
    changed = []
    failed = []

    planned.each do |product, target|
      product.product_series = target
      # The end state is already checked in #plan, so the per-row check is skipped here.
      product.skip_name_uniqueness = true

      if product.save
        changed << product
      else
        failed << Skipped.new(product:, errors: product.errors.full_messages.to_sentence)
      end
    end

    [changed, failed]
  end

  # { group key => product } for the products of the brand that do not change. One query: the
  # groups of all planned changes at the same time. Only the groups the changes land in, so the
  # brand's other products are not read.
  def occupied_groups
    keys = @changes.map { |product| [target_series_id(product), product.name, product.model_no] }.uniq
    return {} if keys.empty?

    values = keys.map do |series_id, name, model_no|
      ActiveRecord::Base.sanitize_sql_array(['(?, ?, ?)', series_id.to_i, name.to_s.downcase, model_no.to_s])
    end.join(', ')

    others = Product.where(brand_id: @series.brand_id)
                    .where.not(id: @changes.map(&:id))
                    .where(<<~SQL.squish)
                      (COALESCE(products.product_series_id, 0), LOWER(products.name),
                       COALESCE(products.model_no, '')) IN (#{values})
                    SQL

    others.each_with_object({}) do |product, memo|
      memo[group_key(product.product_series_id, product.name, product.model_no)] ||= product
    end
  end

  def target_series_id(product)
    @selected_ids.include?(product.id) ? @series.id : nil
  end

  # The group of the uniqueness rule of Product: brand (all products here are of one brand),
  # series, name and model no. A product without a series is in a group of its own.
  def group_key(series_id, name, model_no)
    [series_id.to_i, name.to_s.downcase, model_no.to_s]
  end
end
