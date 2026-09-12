# frozen_string_literal: true

# Fetches candidates for the targets Resolver produced and assembles them into display groups.
#
# One round trip: a UNION ALL of one bounded subquery per target, not a single generic LATERAL.
# Gates differ per target, so a shared WHERE clause would have to encode them as JSONB and
# evaluate them through jsonb_array_elements. They are already modelled as Resolver::Gate, so
# they are built into SQL here instead, where the query log shows each condition literally.
#
# `jsonb_exists_any` / `jsonb_exists` are the function spellings of `?|` / `?`. The operator
# forms cannot be used: `?` is Rails' bind placeholder.
#
# Candidates are base products. A discontinued base product with a current variant is shown as
# that variant (its most complete one), and the swap happens BEFORE ordering, so the row is
# ranked as the reader will see it rather than as the state it is being substituted for.
#
# Roles select; SUB CATEGORIES group. A role pools candidates across its sub categories, but the
# group the reader sees is labelled and linked by the sub category its items are actually in --
# roles like `integrated` (integrated amplifiers + receivers) name no browsable page, and a
# heading linking up to the whole Amplifiers category promises gear the group does not contain.
# Each role renders at most one group: the sub category holding its top-ranked candidate.
class RelatedProducts::Query
  MAX_GROUPS = 4
  PER_GROUP = 4
  # Fetched per target. Larger than PER_GROUP so that a same-brand candidate just outside the
  # top three can still be promoted (docs §7.3), and so the winning sub category still has a
  # useful set once a pooled role's candidates are split by sub category.
  FETCH_PER_GROUP = 12

  UNION_ORDER = 'group_ord ASC, sort_completeness DESC, sort_discontinued ASC, sort_hash ASC'

  Group = Struct.new(:sub_category_id, :items, keyword_init: true)

  def initialize(product:, targets:, product_variant: nil)
    @product = product
    @product_variant = product_variant
    @targets = targets
  end

  def call
    return [] if @targets.empty?

    groups = assemble(fetch)
    groups.reject { |group| group.items.empty? }.first(MAX_GROUPS)
  end

  private

  # docs §6.3: the demotion applies only when the source is current, and for a variant page the
  # variant's own flag decides -- someone viewing a still-current edition is looking at current
  # gear whatever the parent says.
  def source_discontinued?
    return @product_variant.discontinued if @product_variant

    @product.discontinued
  end

  def fetch
    branches = @targets.each_with_index.map { |target, index| "(#{target_sql(target, index)})" }
    # UNION ALL does not preserve the branches' own ordering, so each branch exposes its sort
    # terms as columns and the whole statement is ordered once at the top, over a derived table --
    # a bare UNION ALL of one branch would otherwise collide with that branch's own inner ORDER BY,
    # which is what makes each branch's LIMIT pick the right rows. The inner ORDER BY stays.
    sql = "SELECT * FROM (#{branches.join(' UNION ALL ')}) related_products_candidates ORDER BY #{UNION_ORDER}"
    ActiveRecord::Base.connection.exec_query(sql).group_by { |row| row['group_ord'] }
  end

  def assemble(rows_by_ord)
    item_ids = rows_by_ord.values.flatten.pluck('item_id')
    items = load_items(item_ids)

    @targets.each_with_index.filter_map do |target, index|
      rows = rows_by_ord[index] || []
      sub_category_id, ordered = strongest_sub_category(rows, items)
      next nil if sub_category_id.nil?

      Group.new(sub_category_id:, items: select_items(ordered, target))
    end
  end

  # Presentation reuses the catalogue row presenter, so paths, thumbnails and dates behave as
  # they do in every listing. ProductItem and ContributeProductItem share the id expression, so
  # the ids the query returns address ProductItem rows directly.
  def load_items(item_ids)
    return {} if item_ids.empty?

    relation = ProductItem.where(id: item_ids).includes(:brand)
    relation = ProductItem.preload_list_possession_images(relation)
    relation = ProductItem.preload_sub_category_names(relation)
    relation.index_by(&:id)
  end

  # A role pools candidates across its sub categories; the group shown is the sub category
  # holding the best of them, so the heading names exactly what is listed. Rows arrive ranked,
  # so the first row's sub category wins.
  def strongest_sub_category(rows, items)
    grouped = rows.group_by { |row| row['sub_category_id'] }
    winner = rows.first&.fetch('sub_category_id')
    return [nil, []] if winner.nil?

    [winner, grouped.fetch(winner).filter_map { |row| items[row['item_id']] }]
  end

  # Ruby handles the two set-level rules the ORDER BY cannot express: promote exactly one
  # same-brand item (docs §7.3), and guarantee one candidate still in production (docs §6.3
  # rule 4). Doing them here keeps the SQL to a plain ordering.
  def select_items(ordered, target)
    promoted = promote_same_brand(ordered, target)
    guarantee_in_production(promoted.first(PER_GROUP), promoted, target)
  end

  def promote_same_brand(ordered, target)
    return ordered unless target.same_brand

    index = ordered.index { |item| item.brand_id == @product.brand_id }
    return ordered unless index

    rest = ordered.dup
    [rest.delete_at(index)] + rest
  end

  def guarantee_in_production(selected, pool, target)
    return selected if source_discontinued?
    return selected if RelatedProducts::Graph.consumable?(target.role)
    return selected if selected.none? || selected.any? { |item| !item.discontinued }

    replacement = pool.find { |item| !item.discontinued }
    return selected unless replacement

    selected[0...-1] + [replacement]
  end

  # ------------------------------------------------------------------------------ SQL

  def target_sql(target, index)
    <<~SQL.squish
      SELECT #{index} AS group_ord,
             msc.sub_category_id AS sub_category_id,
             COALESCE(sv.id, base.id) AS item_id,
             COALESCE(sv.completeness, base.completeness) AS sort_completeness,
             #{discontinued_sort_term(target)} AS sort_discontinued,
             hashtext(#{quote(source_hash_key)} || '-' || base.product_id::text) AS sort_hash
      FROM contribute_product_items base
      JOIN LATERAL (
        SELECT psc.sub_category_id
        FROM products_sub_categories psc
        WHERE psc.product_id = base.product_id
          AND psc.sub_category_id = ANY(#{id_array(target.sub_category_ids)})
        ORDER BY array_position(#{id_array(target.sub_category_ids)}, psc.sub_category_id)
        LIMIT 1
      ) msc ON TRUE
      LEFT JOIN LATERAL (
        SELECT v.id, v.completeness, v.discontinued
        FROM contribute_product_items v
        WHERE v.item_type = 'ProductVariant'
          AND v.product_id = base.product_id
          AND v.discontinued = false
        ORDER BY v.completeness DESC, v.id
        LIMIT 1
      ) sv ON base.discontinued
      WHERE base.item_type = 'Product'
        AND base.product_id <> #{@product.id.to_i}
        #{gate_conditions(target)}
      ORDER BY sort_completeness DESC, sort_discontinued ASC, sort_hash ASC
      LIMIT #{FETCH_PER_GROUP}
    SQL
  end

  # A constant when the demotion does not apply -- a discontinued source is not looking for
  # current gear (docs §6.3 rule 3), and consumables are exempt (rule 5). Kept as a column so
  # every branch of the union has the same shape.
  def discontinued_sort_term(target)
    return '0' if source_discontinued? || RelatedProducts::Graph.consumable?(target.role)

    '(COALESCE(sv.discontinued, base.discontinued))::int'
  end

  def source_hash_key
    [@product.id, @product_variant&.id].compact.join(':')
  end

  def gate_conditions(target)
    target.gates.map { |gate| "AND (#{gate_sql(gate)})" }.join(' ')
  end

  def gate_sql(gate)
    key = quote(gate.attribute)
    return presence_sql(key) if gate.presence

    # jsonb_typeof normalises the two storage shapes: an `option` attribute stores one id,
    # an `options` attribute stores an array of them.
    normalised = "(CASE WHEN jsonb_typeof(base.custom_attributes -> #{key}) = 'array' " \
                 "THEN base.custom_attributes -> #{key} " \
                 "ELSE jsonb_build_array(base.custom_attributes -> #{key}) END)"
    overlap = "jsonb_exists_any(#{normalised}, ARRAY[#{text_list(gate.option_ids)}]::text[])"

    return overlap unless gate.negate

    # A negative gate must still require the attribute to be present: unfilled is not the same
    # as known-not-to-match, and fails closed (docs §5.4).
    "jsonb_exists(base.custom_attributes, #{key}) AND NOT #{overlap}"
  end

  # Present means: the key exists, is not JSON null, and -- for an `options` attribute, whose
  # stored value is an array -- is not an empty array.
  def presence_sql(key)
    "jsonb_exists(base.custom_attributes, #{key}) " \
      "AND jsonb_typeof(base.custom_attributes -> #{key}) <> 'null' " \
      "AND (jsonb_typeof(base.custom_attributes -> #{key}) <> 'array' " \
      "OR jsonb_array_length(base.custom_attributes -> #{key}) > 0)"
  end

  # Declared order matters: it decides which sub category a product sitting in two of the
  # target's sub categories is grouped under.
  def id_array(ids)
    "ARRAY[#{ids.map(&:to_i).join(', ')}]::bigint[]"
  end

  def text_list(values)
    values.map { |value| quote(value.to_s) }.join(', ')
  end

  def quote(value)
    ActiveRecord::Base.connection.quote(value)
  end
end
