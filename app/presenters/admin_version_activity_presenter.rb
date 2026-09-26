# frozen_string_literal: true

# Makes a readable sentence and a readable list of changes from a PaperTrail version for
# ActiveAdmin, for example "anna updated the brand Rega" with "Country: Germany → United Kingdom".
#
# Call .preload with the versions of one page first. It returns a Context that the presenters
# share. The context loads the users, the items, and the brands, series and custom attribute
# definitions that the changes refer to, with a fixed number of queries for the full page.
class AdminVersionActivityPresenter
  ITEM_LABELS = {
    'Brand' => 'brand',
    'Product' => 'product',
    'ProductVariant' => 'variant',
    'ProductSeries' => 'series'
  }.freeze

  EVENT_VERBS = {
    'create' => 'created',
    'update' => 'updated',
    'destroy' => 'deleted'
  }.freeze

  # Technical attributes that tell an admin nothing.
  HIDDEN_ATTRIBUTES = %w[slug products_count updated_at].freeze

  Change = Struct.new(:label, :before, :after)

  # Data for all versions of one page.
  class Context
    attr_reader :brand_names, :series_names, :sub_category_names, :custom_attributes

    def initialize(versions)
      @changesets = versions.to_h { |version| [version.id, changeset_of(version)] }
      @brand_names = load_brand_names
      @series_names = load_series_names
      @sub_category_names = load_sub_category_names
      @custom_attributes = load_custom_attributes
    end

    def changeset(version)
      @changesets.fetch(version.id) { changeset_of(version) }
    end

    private

    # The column changes and the association changes (sub categories). See docs/catalog-model.md,
    # "Changelog".
    def changeset_of(version)
      parse(version.object_changes).merge(version.association_changes || {})
    end

    def parse(yaml)
      return {} if yaml.blank?

      PaperTrail::Serializers::YAML.load(yaml) || {}
    end

    def values_of(attribute)
      # Each change is [before, after]. Array() would split a hash value into pairs.
      @changesets.values.flat_map { |changes| changes[attribute] || [] }.compact.uniq
    end

    def load_brand_names
      ids = values_of('brand_id')
      return {} if ids.empty?

      Brand.where(id: ids).pluck(:id, :name, :abbreviation).to_h do |id, name, abbreviation|
        [id, abbreviation.presence || name]
      end
    end

    def load_series_names
      ids = values_of('product_series_id')
      return {} if ids.empty?

      ProductSeries.where(id: ids).pluck(:id, :name).to_h
    end

    def load_sub_category_names
      ids = values_of('sub_category_ids').flatten.uniq
      return {} if ids.empty?

      SubCategory.where(id: ids).pluck(:id, :name).to_h
    end

    def load_custom_attributes
      labels = values_of('custom_attributes').flat_map { |value| AdminVersionActivityPresenter.parse_json(value).keys }
      return {} if labels.empty?

      CustomAttribute.where(label: labels.uniq).index_by(&:label)
    end
  end

  def self.preload(versions)
    versions = versions.to_a
    preload_associations(versions, [:whodunnit_user, :item])

    items = versions.filter_map(&:item)
    preload_associations(items.grep(Product), :brand)
    preload_associations(items.grep(ProductSeries), :brand)
    preload_associations(items.grep(ProductVariant), { product: :brand })
    Context.new(versions)
  end

  def self.preload_associations(records, associations)
    return if records.empty?

    ActiveRecord::Associations::Preloader.new(records:, associations:).call
  end
  private_class_method :preload_associations

  # Custom attributes are stored as a JSON string in older versions and as a hash in newer ones.
  def self.parse_json(value)
    case value
    when Hash then value
    when String then value.present? ? JSON.parse(value) : {}
    else {}
    end
  rescue JSON::ParserError
    {}
  end

  def initialize(version, view, context)
    @version = version
    @view = view
    @context = context
  end

  def sentence
    verb = EVENT_VERBS.fetch(@version.event, @version.event)
    type = ITEM_LABELS.fetch(@version.item_type, @version.item_type.underscore.humanize(capitalize: false))
    @view.safe_join([actor, verb, "the #{type}", item], ' ')
  end

  # truncate: the maximum length of a single text value. Use it for the index; the show page
  # shows the full text.
  def changes(truncate: nil)
    @context.changeset(@version).flat_map do |attribute, (before, after)|
      next [] if HIDDEN_ATTRIBUTES.include?(attribute)
      next custom_attribute_changes(before, after) if attribute == 'custom_attributes'

      before = format_value(attribute, before, truncate)
      after = format_value(attribute, after, truncate)
      next [] if before.nil? && after.nil?

      [Change.new(attribute_label(attribute), before, after)]
    end
  end

  def changes_list(truncate: nil)
    rows = changes(truncate:)
    return @view.tag.em('No visible changes') if rows.empty?

    @view.tag.ul(class: 'AdminActivityChanges') do
      @view.safe_join(rows.map { |change| @view.tag.li(change_line(change)) })
    end
  end

  private

  def change_line(change)
    parts = [@view.tag.strong("#{change.label}:")]
    if change.before.nil?
      parts << @view.tag.ins(change.after)
    elsif change.after.nil?
      parts << @view.tag.del(change.before) << 'removed'
    else
      parts << @view.tag.del(change.before) << '→' << @view.tag.ins(change.after)
    end
    @view.safe_join(parts, ' ')
  end

  def actor
    user = @version.whodunnit_user
    return @view.link_to(user.user_name, @view.admin_user_path(user)) if user
    return @view.tag.em("deleted user ##{@version.whodunnit}") if @version.whodunnit.present?

    # Versions without a user come from the console, imports or admin changes.
    @view.tag.em('System')
  end

  def item
    record = @version.item
    return @view.link_to(record.display_name, admin_item_path(record)) if record

    name = deleted_item_name
    @view.tag.em(name.present? ? "#{name} (deleted)" : "##{@version.item_id} (deleted)")
  end

  def admin_item_path(record)
    case record
    when Brand then @view.admin_brand_path(record)
    when Product then @view.admin_product_path(record)
    when ProductVariant then @view.admin_product_variant_path(record)
    when ProductSeries then @view.admin_product_series_path(record)
    end
  end

  # For a deleted item, the last known name is in the version itself.
  def deleted_item_name
    object = @version.object.present? ? PaperTrail::Serializers::YAML.load(@version.object) : {}
    changes = @context.changeset(@version)
    object&.dig('name').presence || Array(changes['name']).compact.last
  end

  def item_class
    @item_class ||= @version.item_type.safe_constantize
  end

  def attribute_label(attribute)
    item_class ? item_class.human_attribute_name(attribute) : attribute.humanize
  end

  # Returns nil for an empty value, so the change line can say "removed" or show only the new value.
  def format_value(attribute, value, truncate)
    return if value.nil? || value == '' || value == []

    text = case attribute
           when 'brand_id' then @context.brand_names[value] || "##{value} (deleted)"
           when 'product_series_id' then @context.series_names[value] || "##{value} (deleted)"
           when 'sub_category_ids' then sub_category_names(value)
           when 'product_options' then value.join(', ')
           when 'country_code' then @view.country_name_from_country_code(value) || value
           else scalar(value)
           end
    truncate ? text.to_s.truncate(truncate) : text.to_s
  end

  def sub_category_names(ids)
    ids.map { |id| @context.sub_category_names[id] || "##{id} (deleted)" }.join(', ')
  end

  def scalar(value)
    case value
    when true then 'Yes'
    when false then 'No'
    when Time, DateTime, ActiveSupport::TimeWithZone then value.strftime('%d.%m.%Y %H:%M')
    when Date then value.strftime('%d.%m.%Y')
    when BigDecimal, Float then number(value)
    else value.to_s
    end
  end

  def custom_attribute_changes(before, after)
    before = self.class.parse_json(before)
    after = self.class.parse_json(after)

    (before.keys | after.keys).sort.filter_map do |label|
      next if before[label] == after[label]

      definition = @context.custom_attributes[label]
      Change.new(
        I18n.t("custom_attribute_labels.#{label}", default: label.humanize),
        custom_attribute_value(definition, before[label]),
        custom_attribute_value(definition, after[label])
      )
    end
  end

  # Same rules as the public changelog (app/views/shared/_changelog.html.erb), in one line.
  def custom_attribute_value(definition, value)
    return if value.nil? || value == ''

    case value
    when Hash then measured_value(definition, value)
    when Array then value.map { |id| option_name(definition, id) }.join(', ')
    when true, false then value ? 'Yes' : 'No'
    else
      if definition&.input_type == 'boolean'
        value ? 'Yes' : 'No'
      else
        option_name(definition, value)
      end
    end
  end

  def measured_value(definition, value)
    unit = value['unit'].presence || definition&.units&.first
    unit_text = I18n.t("custom_attribute_units.#{unit}", default: unit.to_s) if unit.present?
    inner = value['value']

    text = if inner.is_a?(Hash)
             inner.map do |key, number|
               "#{I18n.t("custom_attribute_inputs.#{key}", default: key)}: #{number(number)}"
             end.join(', ')
           elsif inner.present?
             number(inner)
           else
             'n/a'
           end
    # Unit texts can contain an HTML entity (&ohm;).
    reading = [text, unit_text].compact.join(' ').gsub('&ohm;', 'Ω')

    # Without the condition, a change of the condition alone reads as the same value before and
    # after, so the row looks like a change that did not happen.
    qualifier = CustomAttribute.qualifier_label(value)
    qualifier.present? ? "#{reading} (#{qualifier})" : reading
  end

  def option_name(definition, id)
    key = definition&.options&.[](id.to_s)
    key ? I18n.t("custom_attributes.#{key}", default: key) : id.to_s
  end

  def number(value)
    @view.number_with_precision(value, precision: 4, strip_insignificant_zeros: true)
  end
end
