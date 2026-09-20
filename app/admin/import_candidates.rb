# frozen_string_literal: true

# The review queue.
#
# Eleven thousand candidates cannot be reviewed one form at a time. The screen
# is therefore built for deciding in groups: filter to one brand or one shop
# category, look at the rows, tick them, approve. The ordering puts the rows
# that can be decided quickly first, so the reviewer's first hour is worth more
# than the last.
#
# What a reviewer needs to see without opening a row: where the value came from,
# whether the catalogue already holds this product, and what the importer was
# unsure about. All three are columns.
ActiveAdmin.register ImportCandidate do
  menu parent: 'Import', priority: 1
  # Edit, but no new and no delete: a candidate comes from a crawl, and a
  # refused one is kept, so that the next run does not offer it again.
  actions :index, :show, :edit, :update

  permit_params :brand_id, :name, :variant_name, :model_no, :description, :price,
                :price_currency, :release_year, :discontinued, :diy_kit,
                :decision_note, sub_category_ids: []

  filter :brand
  filter :status, as: :select, collection: ImportCandidate.statuses
  filter :source_category
  filter :source_platform
  filter :name
  filter :model_no
  filter :score
  filter :release_year
  filter :discontinued
  filter :diy_kit
  filter :has_custom_attributes, as: :boolean, label: 'Has custom attributes'
  filter :validation_verdict, as: :select,
                              collection: %w[agreed corrected classified out_of_scope no_category unsure]

  scope :reviewable, default: true
  scope :unvalidated
  scope :validated
  scope :unclassified
  scope :classified
  scope :ready
  scope :imported
  scope :rejected

  # Approving does not write anything to the catalogue. `rake import:promote`
  # does that, in one place, where a failure can be reported and retried.
  batch_action :approve do |ids|
    updated = ImportCandidate.where(id: ids).update_all(
      status: 'approved', reviewed_by_id: current_admin_user.id,
      reviewed_at: Time.current, updated_at: Time.current
    )
    redirect_back fallback_location: admin_import_candidates_path,
                  notice: "#{updated} candidate(s) approved. Run `rake import:promote` to write them."
  end

  batch_action :reject, form: -> { { reason: :text } } do |ids, inputs|
    updated = ImportCandidate.where(id: ids).update_all(
      status: 'rejected', decision_note: inputs[:reason].presence,
      reviewed_by_id: current_admin_user.id,
      reviewed_at: Time.current, updated_at: Time.current
    )
    redirect_back fallback_location: admin_import_candidates_path,
                  notice: "#{updated} candidate(s) rejected."
  end

  # For a whole shop category at once: "everything this brand calls Subwoofer is
  # a subwoofer". The mapping is remembered, so the same word never has to be
  # decided again -- including in every later run.
  # Two choosers rather than one: a product can be two things at once -- the
  # Wisdom Audio SUB1 is a subwoofer and an in-wall loudspeaker -- and a form
  # that offers one would make a reviewer choose wrongly. ActiveAdmin's batch
  # action form has no multiple select, so the second is simply optional.
  batch_action :classify, form: lambda {
    { sub_category: SubCategory.order(:name).pluck(:name, :id),
      and_also: SubCategory.order(:name).pluck(:name, :id),
      remember: :checkbox }
  } do |ids, inputs|
    chosen = [inputs[:sub_category], inputs[:and_also]].compact_blank.map(&:to_i).uniq
    candidates = ImportCandidate.where(id: ids)
    candidates.update_all(
      ['sub_category_ids = ?, updated_at = ?', "{#{chosen.join(',')}}", Time.current]
    )

    unremembered = 0
    if inputs[:remember] == '1'
      candidates.where.not(source_category: [nil, '']).distinct
                .pluck(:brand_id, :source_category).each do |brand_id, word|
        mapping = ImportCategoryMapping.find_or_initialize_by(brand_id: brand_id, source_category: word)
        mapping.sub_category_ids = chosen
        mapping.decided_by = current_admin_user
        unremembered += 1 unless mapping.save
      end
    end
    notice = "#{candidates.size} candidate(s) classified."
    notice += " #{unremembered} mapping(s) could not be remembered." if unremembered.positive?
    redirect_back fallback_location: admin_import_candidates_path, notice: notice
  end

  # The same fields as the product form, for the fields a candidate has. What
  # is saved here is what `rake import:promote` writes. An edited row is marked,
  # and the import tasks do not write over it again.
  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :name
      f.input :variant_name
      f.input :model_no
      f.input :brand
      f.input :release_year
      f.input :discontinued
      f.input :diy_kit
      f.input :price
      f.input :price_currency
      f.input :description
      f.input :decision_note
      f.li class: 'mb-4' do
        f.fieldset do
          f.legend(class: 'font-bold text-xl') { 'Categories' }
          Category.includes(:sub_categories).order(:name).each do |category|
            f.input :sub_category_ids, label: "<b>#{ERB::Util.h(category.name)}</b>".html_safe,
                                       as: :check_boxes, collection: category.sub_categories
          end
        end
      end
    end
    f.actions
  end

  # A grid of cards rather than a table: a candidate has too many fields for
  # one table row, and a card shows all of them without scrolling sideways.
  # The component is app/components/index_as_grid.rb.
  index as: IndexAsGrid, sort_by: { score: 'Score', name: 'Name', release_year: 'Year',
                                    validation_verdict: 'Verdict', updated_at: 'Updated' } do |candidate|
    # Two parts: what becomes the product, and what the import knows about the
    # row. The first part is what `rake import:promote` writes; the second part
    # helps to decide, and is never written to the catalogue.
    section 'aria-label': 'Product data', class: 'flex flex-col gap-3' do
      div do
        if candidate.brand
          link_to(candidate.brand.name, admin_brand_path(candidate.brand))
        else
          status_tag(candidate.brand_slug, class: 'warning')
        end
      end

      # The name is edited in place: a change is saved when the field loses
      # focus or Enter is pressed (app/assets/javascripts/admin_inline_edit.js).
      # The input has no `name` attribute: the grid sits inside the batch action
      # form, and the input must not be sent with a batch action.
      div do
        text_node tag.input(type: 'text', value: candidate.name,
                            'aria-label': "Name of #{candidate}",
                            'data-inline-edit-url': rename_admin_import_candidate_path(candidate),
                            'data-inline-edit-field': 'name',
                            class: 'w-full rounded border border-gray-300 bg-white px-2 py-1 ' \
                                    'dark:border-gray-600 dark:bg-gray-800 ' \
                                    'data-[inline-edit-state=saving]:border-amber-500 ' \
                                    'data-[inline-edit-state=saved]:border-green-600 ' \
                                    'data-[inline-edit-state=error]:border-red-600')
      end

      div class: 'grid grid-cols-2 gap-x-4 gap-y-2' do
        field 'Variant', candidate.variant_name
        field 'Model no', candidate.model_no
        field 'Sub categories', sub_category_names_for(candidate).join(', ')
        field 'Price', ("#{candidate.price} #{candidate.price_currency}" if candidate.price)
        field 'Release year', candidate.release_year
        # Three states: yes, no, and not stated. "Not stated" shows a dash, so
        # that it is not read as "still made".
        field('Discontinued') do
          status_tag(candidate.discontinued ? 'yes' : 'no') unless candidate.discontinued.nil?
        end
        field('DIY kit') do
          candidate.diy_kit ? status_tag('kit', class: 'warning') : 'no'
        end
      end
      div class: 'grid grid-cols-2 gap-x-4 gap-y-2' do
        Array(candidate.custom_attributes).sort.each do |attr_name, attr_data|
          active_record = CustomAttribute.find_by(label: attr_name)
          next if active_record.blank?

          div class: 'text-xs uppercase tracking-wide text-gray-500 dark:text-gray-400' do
            attr_name
          end

          div class: 'break-words text-sm' do
            if attr_data.is_a?(Hash)
              unit = attr_data['unit'].presence || active_record.units.first
              translated_unit = t("custom_attribute_units.#{unit}").html_safe if unit.present?
              equivalent = CustomAttribute.equivalent_unit(unit) if active_record.units.size == 2
              value = attr_data['value']

              if value.is_a?(Hash)
                value.each do |sub_key, sub_val|
                  text_node t("custom_attribute_inputs.#{sub_key}")
                  text_node ": #{number_with_precision(sub_val, precision: 4, strip_insignificant_zeros: true)} "
                  text_node translated_unit
                  if equivalent
                    text_node " / #{number_with_precision(sub_val * equivalent[1], precision: 4, strip_insignificant_zeros: true)} "
                    text_node t("custom_attribute_units.#{equivalent[0]}").html_safe
                  end
                  br
                end
              elsif value.present?
                text_node "#{number_with_precision(value, precision: 4, strip_insignificant_zeros: true)} "
                text_node translated_unit
                if equivalent
                  text_node " / #{number_with_precision(value * equivalent[1], precision: 4, strip_insignificant_zeros: true)} "
                  text_node t("custom_attribute_units.#{equivalent[0]}").html_safe
                end
              else
                text_node "n/a"
              end

            elsif attr_data.is_a?(Array)
              text_node attr_data.map { |id| t("custom_attributes.#{active_record.options[id.to_s]}") }.join(", ")

            elsif active_record[:input_type] == 'boolean'
              text_node t("custom_attributes.#{attr_data ? 'yes' : 'no'}")

            else
              text_node t("custom_attributes.#{active_record.options[attr_data.to_s]}")
            end
          end
        end
      end
    end

    section 'aria-label': 'Import data',
            class: 'flex flex-col gap-3 rounded-md bg-gray-50 p-3 dark:bg-gray-800/60' do
      div 'Import', class: 'text-xs font-bold uppercase tracking-wide text-gray-500 dark:text-gray-400'

      div class: 'grid grid-cols-2 gap-x-4 gap-y-2' do
        field('Status') { status_tag candidate.status }
        # The verdict of the second reading. The note says why; it is shown
        # when the pointer rests on the verdict.
        field('Checked') do
          if candidate.validated?
            span title: [candidate.validation_note, candidate.validated_by].compact_blank.join(' -- ') do
              status_tag(candidate.validation_verdict.presence || 'checked',
                         class: %w[out_of_scope unsure].include?(candidate.validation_verdict) ? 'warning' : 'ok')
            end
          else
            status_tag('not checked', class: 'warning')
          end
        end
        field('In catalogue?') do
          count = duplicate_count_for(candidate)
          status_tag(count.positive? ? "#{count} match" : 'new', class: count.positive? ? 'warning' : 'ok')
        end
        # Not a measure of truth: a well sourced row can still be wrong. It says
        # where the next minute of reviewing is best spent.
        field 'Score', candidate.score
        field 'Shop says', candidate.source_category
        field('Edited') do
          span(candidate.edited_by&.email, title: candidate.edited_at&.to_fs(:short)) if candidate.edited?
        end
      end

      # The full address of the shop page, so that the source of a row is seen
      # without opening it. A long address breaks inside the card.
      field('Shop URL') do
        a candidate.source_url, href: candidate.source_url, target: '_blank', rel: 'noopener',
                                class: 'break-all'
      end

      if candidate.warnings.any?
        ul class: 'list-disc ps-5 text-sm text-amber-700 dark:text-amber-400' do
          candidate.warnings.each { |warning| li warning }
        end
      end
    end

    div class: 'mt-auto flex flex-wrap gap-4 border-t border-gray-200 pt-3 text-sm dark:border-gray-700' do
      a 'Details', href: admin_import_candidate_path(candidate)
      a 'Edit', href: edit_admin_import_candidate_path(candidate)
      # Approve and write the product in one step. Rails UJS sends the POST and
      # asks with the browser's own confirm dialog. A link, not a form: the grid
      # sits inside the batch action form, and forms cannot be nested.
      if candidate.pending? || candidate.approved?
        a 'Publish', href: publish_admin_import_candidate_path(candidate),
                     'data-method': 'post',
                     'data-confirm': "Publish \"#{candidate}\" as a product now?",
                     class: 'ms-auto font-bold'
        a 'Reject', href: reject_admin_import_candidate_path(candidate),
                    'data-method': 'post',
                    'data-confirm': "Reject \"#{candidate}\"?",
                    class: 'font-bold text-red-700 dark:text-red-400'
      end
    end
  end

  show do
    attributes_table do
      row :brand
      row :brand_slug
      row :name
      row :variant_name
      row :model_no
      row('Sub categories') { |candidate| candidate.sub_category_names.join(', ') }
      row :source_category
      row :price do |candidate|
        "#{candidate.price} #{candidate.price_currency}" if candidate.price
      end
      row :release_year
      row :discontinued
      row :description
      row :status
      row :decision_note
      row('Checked by') { |candidate| candidate.validated_by }
      row :validation_verdict
      row :validated_at
      row :validation_note
      row('Edited by') { |candidate| candidate.edited_by&.email }
      row :edited_at
      row :source_url do |candidate|
        link_to candidate.source_url, candidate.source_url, target: '_blank', rel: 'noopener'
      end
      row :warnings do |candidate|
        candidate.warnings.join('; ')
      end
    end

    # The provenance is the reason this row can be trusted or refused in
    # seconds. Every field, where it came from, and the words that stated it.
    panel 'Where each value came from' do
      table_for resource.provenance.sort.map { |field, entry| entry.merge('field' => field) } do
        column('Field') { |entry| entry['field'] }
        column('Source') { |entry| entry['source'] }
        column('Confidence') { |entry| entry['confidence'] }
        # String#truncate, not the view helper: inside an Arbre block the name
        # `truncate` does not reach ActionView, and the call fails.
        column('Stated by') { |entry| entry['snippet'].to_s.truncate(160) }
      end
    end

    panel 'Versions the shop sells' do
      table_for resource.variants do
        column('Name') { |variant| variant['name'] }
        column('Article number') { |variant| variant['sku'] }
        column('Price') { |variant| variant['price'] }
      end
    end

    panel 'Possibly the same product' do
      table_for resource.possible_duplicates.limit(10) do
        column('Product') { |product| link_to product.name, admin_product_path(product) }
        column :model_no
        column(:sub_categories) { |product| product.sub_categories.map(&:name).join(', ') }
      end
    end
  end

  # The work list for the mapping: the shop words that no mapping answers yet,
  # biggest first. Deciding the first two hundred of these classified 45% of the
  # first full run.
  collection_action :unmapped_categories do
    @pairs = ImportCandidate.unmapped_categories
    @brands = Brand.where(id: @pairs.map { |(brand_id, _word), _count| brand_id }.compact).index_by(&:id)
    @sub_categories = SubCategory.order(:name)
    render 'admin/import_candidates/unmapped_categories'
  end

  # The name, from the input in the index table. One field, answered as JSON.
  # It marks the row as edited, as the form does, so that `rake import:load`
  # and `rake import:map` leave it alone from now on.
  # Approve one candidate and write it as a product at once, without
  # `rake import:promote`. The promotion is the same code. When it fails, the
  # candidate goes back to the status it had, so that it does not wait as
  # approved for a promotion that cannot succeed.
  member_action :publish, method: :post do
    previous = resource.status
    resource.update!(status: 'approved', reviewed_by: current_admin_user, reviewed_at: Time.current)
    result = ImportPromotion.call(resource)
    if result.success?
      redirect_back fallback_location: admin_import_candidates_path,
                    notice: "Published \"#{result.product.name}\" as a product."
    else
      resource.update_columns(status: previous, updated_at: Time.current)
      redirect_back fallback_location: admin_import_candidates_path,
                    alert: "\"#{resource}\" was not published: #{result.error}."
    end
  end

  # Reject one candidate from the grid, without going through the batch
  # action's reason form: quick refusal, same fields the batch action sets.
  member_action :reject, method: :post do
    resource.update!(status: 'rejected', reviewed_by: current_admin_user, reviewed_at: Time.current)
    redirect_back fallback_location: admin_import_candidates_path,
                  notice: "\"#{resource}\" was rejected."
  end

  member_action :rename, method: :patch do
    resource.assign_attributes(name: params[:name].to_s.strip,
                               edited_at: Time.current, edited_by: current_admin_user)
    if resource.save
      render json: { value: resource.name }
    else
      render json: { error: resource.errors.full_messages.to_sentence }, status: :unprocessable_content
    end
  end

  action_item :unmapped_categories, only: :index do
    link_to 'Unmapped categories', unmapped_categories_admin_import_candidates_path
  end

  controller do
    def scoped_collection
      super.includes(:brand, :edited_by)
    end

    # A saved edit marks the row, so that `rake import:load` and
    # `rake import:map` leave it alone from now on.
    def update
      resource.assign_attributes(edited_at: Time.current, edited_by: current_admin_user)
      super
    end

    helper_method :sub_category_names_for, :duplicate_count_for

    # One query for the whole page rather than one per card: the grid renders
    # up to a few dozen candidates at once, and asking per candidate is the
    # eleven-thousand-query screen the mapping work list comment warns about.
    def sub_category_names_for(candidate)
      sub_category_name_lookup[candidate.id] || []
    end

    def sub_category_name_lookup
      @sub_category_name_lookup ||= begin
        ids = collection.flat_map(&:sub_category_ids).uniq
        names = SubCategory.where(id: ids).order(:order, :name).pluck(:id, :name).to_h
        collection.index_by(&:id).transform_values do |candidate|
          candidate.sub_category_ids.filter_map { |id| names[id] }
        end
      end
    end

    # Two queries for the whole page instead of up to two per card: one for the
    # model-number matches, one for the name matches, both scoped to the
    # brands actually shown.
    def duplicate_count_for(candidate)
      duplicate_counts[candidate.id] || 0
    end

    def duplicate_counts
      @duplicate_counts ||= begin
        candidates = collection.to_a
        brand_ids = candidates.filter_map(&:brand_id).uniq
        products = Product.where(brand_id: brand_ids).pluck(:brand_id, :model_no, :name)
        by_model = products.group_by { |brand_id, model_no, _name| [brand_id, model_no] }
        by_name = products.group_by { |brand_id, _model_no, name| [brand_id, name.downcase] }

        candidates.index_by(&:id).transform_values do |candidate|
          next 0 if candidate.brand_id.blank?

          matches = if candidate.model_no.present?
                      by_model[[candidate.brand_id, candidate.model_no]]
                    end
          matches ||= by_name[[candidate.brand_id, candidate.name.to_s.downcase]]
          [matches&.size || 0, 2].min
        end
      end
    end
  end
end
